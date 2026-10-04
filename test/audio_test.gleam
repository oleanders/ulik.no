import gleam/list
import gleam/result
import gleeunit/should
import lustre/dev/query
import pages/morse
import pages/nato

fn morse_step(model: morse.Model, message: morse.Message) -> morse.Model {
  morse.update(model, message).0
}

fn nato_step(model: nato.Model, message: nato.Message) -> nato.Model {
  nato.update(model, message).0
}

pub fn morse_overview_contains_all_letters_and_digits_test() {
  morse.init("oversikt")
  |> morse.view
  |> query.find_all(query.element(query.class("letter-tile")))
  |> list.length
  |> should.equal(36)
}

pub fn morse_speed_is_bounded_test() {
  let initial = morse.init("oversikt")
  [
    initial.wpm,
    morse_step(initial, morse.ChangeSpeed("0")).wpm,
    morse_step(initial, morse.ChangeSpeed("100")).wpm,
  ]
  |> should.equal([15, 5, 30])
}

pub fn morse_invalid_speed_keeps_previous_value_test() {
  morse.init("oversikt")
  |> morse_step(morse.ChangeSpeed("bad"))
  |> fn(model) { model.wpm }
  |> should.equal(15)
}

pub fn morse_receive_normalizes_answer_test() {
  morse.init("motta")
  |> morse_step(morse.TargetChosen("A"))
  |> morse_step(morse.ChangeAnswer(" a "))
  |> morse_step(morse.Submit)
  |> fn(model) {
    list.map(model.history, fn(entry) { #(entry.answer, entry.correct) })
  }
  |> should.equal([#("A", True)])
}

pub fn morse_press_duration_boundaries_test() {
  morse.init("sende")
  |> morse_step(morse.TargetChosen("A"))
  |> morse_step(morse.PressKey(100.0))
  |> morse_step(morse.ReleaseKey(139.0))
  |> morse_step(morse.PressKey(200.0))
  |> morse_step(morse.ReleaseKey(449.0))
  |> morse_step(morse.PressKey(500.0))
  |> morse_step(morse.ReleaseKey(750.0))
  |> morse_step(morse.Submit)
  |> fn(model) {
    list.map(model.history, fn(entry) { #(entry.answer, entry.correct) })
  }
  |> should.equal([#("A", True)])
}

pub fn morse_repeat_press_does_not_restart_timer_test() {
  morse.init("sende")
  |> morse_step(morse.TargetChosen("T"))
  |> morse_step(morse.PressKey(100.0))
  |> morse_step(morse.PressKey(340.0))
  |> morse_step(morse.ReleaseKey(350.0))
  |> morse_step(morse.Submit)
  |> fn(model) { model.streak }
  |> should.equal(1)
}

pub fn morse_manual_editing_and_duplicate_submission_test() {
  morse.init("sende")
  |> morse_step(morse.TargetChosen("A"))
  |> morse_step(morse.AddSymbol("-"))
  |> morse_step(morse.ClearBuffer)
  |> morse_step(morse.AddSymbol("."))
  |> morse_step(morse.AddSymbol("."))
  |> morse_step(morse.Backspace)
  |> morse_step(morse.AddSymbol("-"))
  |> morse_step(morse.Submit)
  |> morse_step(morse.Submit)
  |> fn(model) { #(model.streak, list.length(model.history)) }
  |> should.equal(#(1, 1))
}

pub fn morse_wrong_answer_resets_streak_test() {
  morse.init("sende")
  |> morse_step(morse.TargetChosen("E"))
  |> morse_step(morse.AddSymbol("."))
  |> morse_step(morse.Submit)
  |> morse_step(morse.TargetChosen("T"))
  |> morse_step(morse.AddSymbol("."))
  |> morse_step(morse.Submit)
  |> fn(model) {
    #(model.streak, list.map(model.history, fn(entry) { entry.correct }))
  }
  |> should.equal(#(0, [False, True]))
}

pub fn morse_stale_playback_events_are_ignored_test() {
  let initial = morse.init("oversikt") |> morse_step(morse.PlayLetter("A"))
  let updated =
    initial
    |> morse_step(morse.Signal(99, True))
    |> morse_step(morse.PlaybackDone(99))
  updated |> should.equal(initial)
}

pub fn morse_current_playback_events_update_light_test() {
  let playing =
    morse.init("oversikt")
    |> morse_step(morse.PlayLetter("A"))
    |> morse_step(morse.Signal(1, True))
  playing.playback |> should.equal(morse.Playing(1, "A", True))
  morse_step(playing, morse.PlaybackDone(1)).playback
  |> should.equal(morse.Silent)
}

pub fn morse_playing_blocks_repeated_playback_test() {
  let playing = morse.init("oversikt") |> morse_step(morse.PlayLetter("A"))
  morse_step(playing, morse.PlayLetter("B")) |> should.equal(playing)
}

pub fn morse_invalid_letter_is_ignored_test() {
  let initial = morse.init("oversikt")
  morse_step(initial, morse.PlayLetter("SHIFT")) |> should.equal(initial)
}

pub fn morse_empty_send_is_not_scored_test() {
  morse.init("sende")
  |> morse_step(morse.TargetChosen("A"))
  |> morse_step(morse.Submit)
  |> fn(model) { model.history }
  |> should.equal([])
}

pub fn morse_answered_round_cannot_be_edited_test() {
  let answered =
    morse.init("sende")
    |> morse_step(morse.TargetChosen("E"))
    |> morse_step(morse.AddSymbol("."))
    |> morse_step(morse.Submit)
  answered
  |> morse_step(morse.AddSymbol("-"))
  |> morse_step(morse.Backspace)
  |> morse_step(morse.ClearBuffer)
  |> should.equal(answered)
}

pub fn morse_timing_and_dictionary_roundtrip_test() {
  morse.signal_durations("A", 15) |> should.equal([80.0, 240.0])
  morse.alphabet
  |> list.each(fn(entry) {
    morse.decode_morse(morse.morse_code(entry.0)) |> should.equal(Ok(entry.0))
  })
}

pub fn nato_round_length_settings_are_ordered_and_bounded_test() {
  nato.init()
  |> nato_step(nato.ChangeMinimum("99"))
  |> nato_step(nato.ChangeMaximum("-3"))
  |> fn(model) { #(model.min_words, model.max_words) }
  |> should.equal(#(5, 5))
}

pub fn nato_answers_normalize_punctuation_test() {
  nato.init()
  |> nato_step(
    nato.RoundChosen(1, [nato.Entry("A", "Alfa"), nato.Entry("B", "Bravo")]),
  )
  |> nato_step(nato.ChangeAnswer("a- b!"))
  |> nato_step(nato.Submit)
  |> fn(model) {
    #(
      model.feedback,
      list.flat_map(model.history, fn(entry) {
        list.map(entry.letters, fn(letter) { letter.correct })
      }),
    )
  }
  |> should.equal(#("Riktig! Alfa Bravo = AB.", [True, True]))
}

pub fn nato_missing_letters_are_recorded_test() {
  nato.init()
  |> nato_step(
    nato.RoundChosen(1, [nato.Entry("A", "Alfa"), nato.Entry("B", "Bravo")]),
  )
  |> nato_step(nato.ChangeAnswer("A"))
  |> nato_step(nato.Submit)
  |> fn(model) {
    list.flat_map(model.history, fn(entry) {
      list.map(entry.letters, fn(letter) { #(letter.user, letter.correct) })
    })
  }
  |> should.equal([#("A", True), #("∅", False)])
}

pub fn nato_duplicate_submission_is_ignored_test() {
  nato.init()
  |> nato_step(nato.RoundChosen(1, [nato.Entry("A", "Alfa")]))
  |> nato_step(nato.Submit)
  |> nato_step(nato.Submit)
  |> fn(model) { list.length(model.history) }
  |> should.equal(1)
}

pub fn nato_history_newest_first_test() {
  nato.init()
  |> nato_step(nato.RoundChosen(1, [nato.Entry("A", "Alfa")]))
  |> nato_step(nato.Submit)
  |> nato_step(nato.RoundChosen(2, [nato.Entry("B", "Bravo")]))
  |> nato_step(nato.Submit)
  |> fn(model) { list.map(model.history, fn(entry) { entry.number }) }
  |> should.equal([2, 1])
}

pub fn nato_unsupported_speech_has_capability_message_test() {
  nato.init()
  |> nato_step(nato.SpeechUnavailable)
  |> fn(model) { model.feedback }
  |> should.equal(
    "Nettleseren din støtter ikke taleavspilling via Speech Synthesis.",
  )
}

pub fn nato_stale_speech_events_do_not_stop_current_round_test() {
  let playing =
    nato.init()
    |> nato_step(nato.VoicesLoaded([]))
    |> nato_step(nato.RoundChosen(1, [nato.Entry("A", "Alfa")]))
  playing
  |> nato_step(nato.SpeechEnded(99))
  |> nato_step(nato.SpeechFailed(99))
  |> should.equal(playing)
  nato_step(playing, nato.SpeechEnded(1)).playback |> should.equal(nato.Quiet)
}

pub fn nato_voice_prefers_exact_language_then_prefix_then_fallback_test() {
  let norwegian = nato.Voice("nb", "nb-NO")
  let american = nato.Voice("us", "en-US")
  let british = nato.Voice("gb", "en-GB")
  nato.matching_voice(nato.BritishEnglish, [norwegian, american, british])
  |> should.equal(Ok(british))
  nato.matching_voice(nato.BritishEnglish, [norwegian, american])
  |> should.equal(Ok(american))
  nato.matching_voice(nato.Nynorsk, [norwegian, american])
  |> should.equal(Ok(norwegian))
  nato.matching_voice(nato.Bokmal, []) |> should.equal(Error(Nil))
}

pub fn nato_next_round_requires_submission_test() {
  let playing =
    nato.init() |> nato_step(nato.RoundChosen(1, [nato.Entry("A", "Alfa")]))
  nato_step(playing, nato.NextRound) |> should.equal(playing)
  playing
  |> nato_step(nato.Submit)
  |> nato_step(nato.NextRound)
  |> fn(model) { model.game }
  |> should.equal(nato.Loading(2))
}

pub fn nato_history_score_is_in_view_test() {
  nato.init()
  |> nato_step(nato.RoundChosen(1, [nato.Entry("A", "Alfa")]))
  |> nato_step(nato.ChangeAnswer("A"))
  |> nato_step(nato.Submit)
  |> nato.view
  |> query.find(
    query.element(query.text("Oppsummering: 1/1 riktige bokstaver (100%)")),
  )
  |> result.is_ok
  |> should.be_true
}
