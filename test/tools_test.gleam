import gleam/list
import gleam/string
import gleeunit/should
import lustre/element
import pages/diff
import pages/screen

pub fn diff_statistics_count_lines_and_characters_test() {
  let changes = [
    diff.Change("same", 1, False, False),
    diff.Change("new\nline\n", 2, True, False),
    diff.Change("old\n", 1, False, True),
  ]
  diff.statistics(diff.Lines, changes) |> should.equal(diff.Statistics(2, 1))
  diff.statistics(diff.Words, changes) |> should.equal(diff.Statistics(9, 4))
  diff.statistics(diff.Words, [diff.Change("🙂", 1, True, False)])
  |> should.equal(diff.Statistics(2, 0))
}

pub fn diff_initial_example_is_computed_test() {
  let model = diff.init()
  diff.statistics(model.mode, model.changes)
  |> should.equal(diff.Statistics(3, 2))
}

pub fn diff_swap_and_clear_recompute_immediately_test() {
  let initial = diff.init()
  let #(swapped, _) = diff.update(initial, diff.Swap)
  let #(cleared, _) = diff.update(swapped, diff.Clear)
  #(swapped.left, swapped.right) |> should.equal(#(initial.right, initial.left))
  #(cleared.left, cleared.right) |> should.equal(#("", ""))
  cleared.changes |> should.equal([])
  diff.statistics(swapped.mode, swapped.changes)
  |> should.equal(diff.Statistics(2, 3))
}

pub fn diff_editing_and_word_mode_preserve_spaces_test() {
  let #(model, _) = diff.update(diff.init(), diff.EditLeft("a b"))
  let #(model, _) = diff.update(model, diff.EditRight("a  c"))
  let #(model, _) = diff.update(model, diff.SetMode(diff.Words))
  model.mode |> should.equal(diff.Words)
  model.changes
  |> list.filter(fn(change) { !change.added })
  |> list.map(fn(change) { change.value })
  |> string.concat
  |> should.equal("a b")
  model.changes
  |> list.filter(fn(change) { !change.removed })
  |> list.map(fn(change) { change.value })
  |> string.concat
  |> should.equal("a  c")
}

pub fn diff_empty_and_identical_messages_test() {
  let #(empty, _) = diff.update(diff.init(), diff.Clear)
  empty
  |> diff.view
  |> element.to_string
  |> string.contains("ingen inndata enda.")
  |> should.be_true
  let #(same, _) = diff.update(empty, diff.EditLeft("same"))
  let #(same, _) = diff.update(same, diff.EditRight("same"))
  same
  |> diff.view
  |> element.to_string
  |> string.contains("tekstene er identiske.")
  |> should.be_true
}

pub fn diff_renders_untrusted_input_as_text_test() {
  let #(model, _) = diff.update(diff.init(), diff.EditLeft(""))
  let #(model, _) =
    diff.update(model, diff.EditRight("<script>alert('x')</script>"))
  let rendered = model |> diff.view |> element.to_string
  rendered |> string.contains("<script>") |> should.be_false
  rendered |> string.contains("&lt;script&gt;") |> should.be_true
}

pub fn screen_support_and_audio_are_typed_test() {
  let initial = screen.init()
  initial.supported |> should.be_false
  let #(supported, _) = screen.update(initial, screen.Support(True))
  let #(audio, _) = screen.update(supported, screen.IncludeAudio(True))
  #(audio.supported, audio.include_audio) |> should.equal(#(True, True))
}

pub fn screen_start_event_updates_label_and_controls_test() {
  let #(model, _) = screen.update(screen.init(), screen.Started("Test window"))
  #(model.share_state, model.source_label, model.status_text)
  |> should.equal(#(screen.Sharing, "Test window", "Skjermdeling er aktiv."))
  let rendered = model |> screen.view |> element.to_string
  rendered |> string.contains("data-active=\"true\"") |> should.be_true
  rendered |> string.contains("id=\"screen-preview\"") |> should.be_true
}

pub fn screen_external_stop_clears_source_and_announces_browser_stop_test() {
  let #(model, _) = screen.update(screen.init(), screen.Started("Window"))
  let #(model, _) = screen.update(model, screen.Stopped)
  #(model.share_state, model.source_label, model.status_text)
  |> should.equal(#(
    screen.Idle,
    "Ingen aktiv kilde",
    "Skjermdeling ble stoppet fra nettleseren.",
  ))
}

pub fn screen_manual_stop_no_longer_claims_to_be_active_test() {
  let #(model, _) = screen.update(screen.init(), screen.Started("Window"))
  let #(model, _) = screen.update(model, screen.Stop)
  #(model.share_state, model.source_label, model.status_text)
  |> should.equal(#(
    screen.Idle,
    "Ingen aktiv kilde",
    "Skjermdeling er stoppet.",
  ))
}

pub fn screen_api_failure_preserves_useful_error_test() {
  let message = "Fant ingen skjermkilder å dele."
  let #(model, _) = screen.update(screen.init(), screen.ShareFailed(message))
  #(model.share_state, model.status_text)
  |> should.equal(#(screen.Failed, message))
}

pub fn screen_error_and_source_labels_are_rendered_as_text_test() {
  let #(model, _) =
    screen.update(screen.init(), screen.ShareFailed("<script>bad</script>"))
  let rendered = model |> screen.view |> element.to_string
  rendered |> string.contains("<script>") |> should.be_false
  rendered |> string.contains("&lt;script&gt;") |> should.be_true
}

pub fn screen_does_not_start_an_unsupported_or_active_capture_test() {
  let initial = screen.init()
  let #(unsupported, _) = screen.update(initial, screen.Start)
  unsupported |> should.equal(initial)
  let #(active, _) = screen.update(initial, screen.Started("Window"))
  let #(repeated, _) = screen.update(active, screen.Start)
  repeated |> should.equal(active)
}
