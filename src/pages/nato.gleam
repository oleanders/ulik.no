import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e

pub type Entry {
  Entry(letter: String, word: String)
}

pub type Game {
  Setup
  Loading(Int)
  Playing(Round)
}

pub type Round {
  Round(
    number: Int,
    entries: List(Entry),
    answer: String,
    reveal_words: Bool,
    outcome: Outcome,
  )
}

pub type Outcome {
  AwaitingAnswer
  Answered(List(LetterResult))
}

pub type LetterResult {
  LetterResult(word: String, expected: String, user: String, correct: Bool)
}

pub type HistoryEntry {
  HistoryEntry(number: Int, letters: List(LetterResult))
}

pub type Language {
  Bokmal
  Nynorsk
  AmericanEnglish
  BritishEnglish
}

pub type Voice {
  Voice(uri: String, language: String)
}

pub type Speech {
  CheckingSupport
  Unavailable
  Available(List(Voice))
}

pub type Playback {
  Quiet
  Speaking(Int)
}

pub type Model {
  Model(
    game: Game,
    min_words: Int,
    max_words: Int,
    language: Language,
    speech: Speech,
    playback: Playback,
    next_request: Int,
    feedback: String,
    history: List(HistoryEntry),
  )
}

pub type Message {
  ChangeMinimum(String)
  ChangeMaximum(String)
  ChangeLanguage(String)
  StartGame
  NextRound
  RoundChosen(Int, List(Entry))
  ChangeAnswer(String)
  Submit
  ToggleWords
  SpeakRound
  VoicesLoaded(List(Voice))
  SpeechUnavailable
  SpeechEnded(Int)
  SpeechFailed(Int)
}

pub fn init() -> Model {
  Model(Setup, 3, 5, Bokmal, CheckingSupport, Quiet, 1, "", [])
}

pub fn mount() -> Effect(Message) {
  effect.from(fn(dispatch) {
    init_speech(
      fn(voices) {
        dispatch(
          VoicesLoaded(list.map(voices, fn(voice) { Voice(voice.0, voice.1) })),
        )
      },
      fn() { dispatch(SpeechUnavailable) },
    )
  })
}

@external(javascript, "../audio_ffi.mjs", "dispose")
pub fn dispose() -> Nil

@external(javascript, "../audio_ffi.mjs", "init_speech")
fn init_speech(
  on_voices: fn(List(#(String, String))) -> Nil,
  on_unavailable: fn() -> Nil,
) -> Nil

@external(javascript, "../audio_ffi.mjs", "speak")
fn speak(
  request: Int,
  text: String,
  language: String,
  voice_uri: String,
  on_ended: fn(Int) -> Nil,
  on_failed: fn(Int) -> Nil,
) -> Nil

@external(javascript, "../audio_ffi.mjs", "stop_speech")
fn stop_speech() -> Nil

@external(javascript, "../audio_ffi.mjs", "random_between")
fn random_between(minimum: Int, maximum: Int) -> Int

@external(javascript, "../audio_ffi.mjs", "focus")
fn focus_element(id: String) -> Nil

pub const alphabet: List(Entry) = [
  Entry("A", "Alfa"),
  Entry("B", "Bravo"),
  Entry("C", "Charlie"),
  Entry("D", "Delta"),
  Entry("E", "Echo"),
  Entry("F", "Foxtrot"),
  Entry("G", "Golf"),
  Entry("H", "Hotel"),
  Entry("I", "India"),
  Entry("J", "Juliett"),
  Entry("K", "Kilo"),
  Entry("L", "Lima"),
  Entry("M", "Mike"),
  Entry("N", "November"),
  Entry("O", "Oscar"),
  Entry("P", "Papa"),
  Entry("Q", "Quebec"),
  Entry("R", "Romeo"),
  Entry("S", "Sierra"),
  Entry("T", "Tango"),
  Entry("U", "Uniform"),
  Entry("V", "Victor"),
  Entry("W", "Whiskey"),
  Entry("X", "X-ray"),
  Entry("Y", "Yankee"),
  Entry("Z", "Zulu"),
]

const languages = [
  #(Bokmal, "Norsk bokmål (nb-NO)"),
  #(Nynorsk, "Norsk nynorsk (nn-NO)"),
  #(AmericanEnglish, "Engelsk (USA) (en-US)"),
  #(BritishEnglish, "Engelsk (Storbritannia) (en-GB)"),
]

pub fn language_code(language: Language) -> String {
  case language {
    Bokmal -> "nb-NO"
    Nynorsk -> "nn-NO"
    AmericanEnglish -> "en-US"
    BritishEnglish -> "en-GB"
  }
}

fn language_from_string(language: String) -> Language {
  case language {
    "nn-NO" -> Nynorsk
    "en-US" -> AmericanEnglish
    "en-GB" -> BritishEnglish
    _ -> Bokmal
  }
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    ChangeMinimum(raw) -> #(
      Model(
        ..model,
        min_words: raw
          |> int.parse
          |> result.unwrap(model.min_words)
          |> int.clamp(1, model.max_words),
      ),
      effect.none(),
    )
    ChangeMaximum(raw) -> #(
      Model(
        ..model,
        max_words: raw
          |> int.parse
          |> result.unwrap(model.max_words)
          |> int.clamp(model.min_words, 10),
      ),
      effect.none(),
    )
    ChangeLanguage(raw) -> #(
      Model(..model, language: language_from_string(raw)),
      effect.none(),
    )
    StartGame ->
      case model.game {
        Setup -> begin_round(1, Model(..model, history: []))
        _ -> #(model, effect.none())
      }
    NextRound ->
      case model.game {
        Playing(Round(outcome: Answered(_), number: number, ..)) ->
          begin_round(number + 1, model)
        _ -> #(model, effect.none())
      }
    RoundChosen(number, entries) -> {
      let next =
        Model(
          ..model,
          game: Playing(Round(number, entries, "", False, AwaitingAnswer)),
          feedback: "",
        )
      let #(next, speech) = speak_round(next)
      #(next, effect.batch([speech, focus("answer")]))
    }
    ChangeAnswer(answer) -> #(
      map_round(model, fn(current) { Round(..current, answer: answer) }),
      effect.none(),
    )
    Submit -> submit(model)
    ToggleWords -> #(
      map_round(model, fn(current) {
        Round(..current, reveal_words: !current.reveal_words)
      }),
      effect.none(),
    )
    SpeakRound -> speak_round(model)
    VoicesLoaded(voices) -> #(
      Model(..model, speech: Available(voices)),
      effect.none(),
    )
    SpeechUnavailable -> #(
      Model(
        ..model,
        speech: Unavailable,
        feedback: "Nettleseren din støtter ikke taleavspilling via Speech Synthesis.",
      ),
      effect.none(),
    )
    SpeechEnded(request) ->
      case model.playback == Speaking(request) {
        True -> #(Model(..model, playback: Quiet), effect.none())
        False -> #(model, effect.none())
      }
    SpeechFailed(request) ->
      case model.playback == Speaking(request) {
        True -> #(
          Model(
            ..model,
            playback: Quiet,
            feedback: "Klarte ikke å spille av tale i nettleseren.",
          ),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
  }
}

fn begin_round(number: Int, model: Model) -> #(Model, Effect(Message)) {
  #(
    Model(..model, game: Loading(number), playback: Quiet, feedback: ""),
    effect.from(fn(dispatch) {
      stop_speech()
      let entries =
        numbers(1, random_between(model.min_words, model.max_words))
        |> list.map(fn(_) {
          alphabet
          |> list.drop(random_between(0, 25))
          |> list.first
          |> result.unwrap(Entry("A", "Alfa"))
        })
      dispatch(RoundChosen(number, entries))
    }),
  )
}

fn map_round(model: Model, transform: fn(Round) -> Round) -> Model {
  case model.game {
    Playing(current) -> Model(..model, game: Playing(transform(current)))
    _ -> model
  }
}

pub fn round_words(current: Round) -> String {
  current.entries |> list.map(fn(entry) { entry.word }) |> string.join(" ")
}

pub fn expected_answer(current: Round) -> String {
  current.entries |> list.map(fn(entry) { entry.letter }) |> string.concat
}

pub fn normalize_answer(answer: String) -> String {
  answer
  |> string.uppercase
  |> string.to_graphemes
  |> list.filter(fn(letter) {
    string.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ", letter)
  })
  |> string.concat
}

fn submit(model: Model) -> #(Model, Effect(Message)) {
  case model.game {
    Playing(current) if current.outcome == AwaitingAnswer -> {
      let normalized = normalize_answer(current.answer)
      let results =
        list.index_map(current.entries, fn(entry, index) {
          let letter = string.slice(normalized, index, 1)
          let user = case letter {
            "" -> "∅"
            _ -> letter
          }
          LetterResult(entry.word, entry.letter, user, user == entry.letter)
        })
      let correct = count_correct(results)
      let feedback = case correct == list.length(current.entries) {
        True ->
          "Riktig! "
          <> round_words(current)
          <> " = "
          <> expected_answer(current)
          <> "."
        False ->
          int.to_string(correct)
          <> "/"
          <> int.to_string(list.length(current.entries))
          <> " riktige. Riktig svar er "
          <> expected_answer(current)
          <> " ("
          <> round_words(current)
          <> ")."
      }
      #(
        Model(
          ..model,
          game: Playing(
            Round(..current, reveal_words: True, outcome: Answered(results)),
          ),
          history: [HistoryEntry(current.number, results), ..model.history],
          feedback: feedback,
        ),
        focus("next-round"),
      )
    }
    _ -> #(model, effect.none())
  }
}

fn count_correct(results: List(LetterResult)) -> Int {
  results |> list.filter(fn(letter) { letter.correct }) |> list.length
}

fn is_answered(current: Round) -> Bool {
  current.outcome != AwaitingAnswer
}

fn speech_supported(speech: Speech) -> Bool {
  case speech {
    Available(_) -> True
    _ -> False
  }
}

pub fn matching_voice(
  language: Language,
  voices: List(Voice),
) -> Result(Voice, Nil) {
  let requested = language_code(language) |> string.lowercase
  let prefix = requested |> string.split("-") |> list.first |> result.unwrap("")
  [
    fn(candidate) { candidate == requested },
    fn(candidate) { string.starts_with(candidate, prefix <> "-") },
    fn(candidate) { string.starts_with(candidate, "nb") },
    fn(candidate) { string.starts_with(candidate, "no") },
    fn(candidate) { string.starts_with(candidate, "en") },
  ]
  |> list.find_map(fn(matches) {
    list.find(voices, fn(voice) { matches(string.lowercase(voice.language)) })
  })
}

fn speak_round(model: Model) -> #(Model, Effect(Message)) {
  case model.game, model.speech {
    Playing(current), Available(voices) -> {
      let voice_uri =
        matching_voice(model.language, voices)
        |> result.map(fn(voice) { voice.uri })
        |> result.unwrap("")
      #(
        Model(
          ..model,
          playback: Speaking(model.next_request),
          next_request: model.next_request + 1,
        ),
        effect.from(fn(dispatch) {
          speak(
            model.next_request,
            round_words(current),
            language_code(model.language),
            voice_uri,
            fn(request) { dispatch(SpeechEnded(request)) },
            fn(request) { dispatch(SpeechFailed(request)) },
          )
        }),
      )
    }
    _, _ -> #(model, effect.none())
  }
}

fn focus(id: String) -> Effect(Message) {
  effect.before_paint(fn(_, _) { focus_element(id) })
}

pub fn view(model: Model) -> Element(Message) {
  h.div([a.class("nato-page")], [
    h.section([a.class("terminal-panel head")], [
      h.p([a.class("prompt")], [h.text("$ ./fonetisk-spill --start")]),
      h.div([a.class("head-row")], [
        h.h1([], [h.text("fonetisk≠spill")]),
        h.span([a.class("status active")], [h.text("aktiv")]),
      ]),
      h.p([a.class("description")], [
        h.text(
          "Øv deg på det fonetiske alfabetet ved å høre ord (for eksempel ",
        ),
        h.code([], [h.text("alfa")]),
        h.text(" og "),
        h.code([], [h.text("bravo")]),
        h.text(") og skriv riktige bokstaver."),
      ]),
    ]),
    h.section(
      [a.class("terminal-panel game")],
      list.append(
        case model.game {
          Setup -> setup_view(model)
          Loading(number) -> [
            h.p([a.class("prompt"), a.attribute("aria-live", "polite")], [
              h.text("$ play --round " <> int.to_string(number)),
            ]),
          ]
          Playing(current) -> [
            h.div([a.class("game-layout")], [
              round_view(model, current),
              history_view(model.history),
            ]),
          ]
        },
        case model.feedback {
          "" -> []
          feedback -> [
            h.p([a.class("feedback"), a.attribute("aria-live", "polite")], [
              h.text(feedback),
            ]),
          ]
        },
      ),
    ),
  ])
}

fn setup_view(model: Model) -> List(Element(Message)) {
  [
    h.p([a.class("prompt")], [h.text("$ play --start")]),
    h.p([a.class("description")], [
      h.text(
        "Trykk start for å begynne. Ordene leses opp automatisk i hver runde.",
      ),
    ]),
    h.div([a.class("round-settings")], [
      h.p([a.class("settings-title")], [h.text("Antall ord per oppgave")]),
      h.div([a.class("settings-grid")], [
        h.label([a.for("min-words")], [
          h.text("Min"),
          h.select(
            [
              a.id("min-words"),
              a.attribute("aria-label", "Min"),
              a.value(int.to_string(model.min_words)),
              e.on_input(ChangeMinimum),
            ],
            list.map(numbers(1, model.max_words), word_option(
              model.min_words,
              _,
            )),
          ),
        ]),
        h.label([a.for("max-words")], [
          h.text("Maks"),
          h.select(
            [
              a.id("max-words"),
              a.attribute("aria-label", "Maks"),
              a.value(int.to_string(model.max_words)),
              e.on_input(ChangeMaximum),
            ],
            list.map(numbers(model.min_words, 10), word_option(
              model.max_words,
              _,
            )),
          ),
        ]),
      ]),
      h.p([a.class("settings-hint")], [
        h.text("Velg mellom 1 og 10. Standard er 3–5."),
      ]),
    ]),
    h.div([a.class("actions")], [
      h.button([a.type_("button"), e.on_click(StartGame)], [
        h.text("Start spill"),
      ]),
    ]),
  ]
}

fn word_option(current: Int, number: Int) -> Element(Message) {
  h.option(
    [a.value(int.to_string(number)), a.selected(current == number)],
    int.to_string(number),
  )
}

fn round_view(model: Model, current: Round) -> Element(Message) {
  let unavailable = !speech_supported(model.speech) || model.playback != Quiet
  h.div(
    [a.class("game-main")],
    list.flatten([
      [
        h.p([a.class("prompt")], [
          h.text("$ play --round " <> int.to_string(current.number)),
        ]),
        h.div([a.class("voice-settings")], [
          h.label([a.for("speech-language")], [h.text("Språk for opplesning")]),
          h.select(
            [
              a.id("speech-language"),
              a.value(language_code(model.language)),
              e.on_input(ChangeLanguage),
              a.disabled(unavailable),
            ],
            list.map(languages, fn(language) {
              h.option(
                [
                  a.value(language_code(language.0)),
                  a.selected(model.language == language.0),
                ],
                language.1,
              )
            }),
          ),
        ]),
        h.div([a.class("actions")], [
          h.button(
            [a.type_("button"), e.on_click(SpeakRound), a.disabled(unavailable)],
            [
              h.text(case model.playback {
                Quiet -> "Spill av ord igjen"
                _ -> "Spiller av…"
              }),
            ],
          ),
          h.button(
            [
              a.id("next-round"),
              a.type_("button"),
              a.class(case is_answered(current) {
                True -> "ghost ready"
                False -> "ghost"
              }),
              e.on_click(NextRound),
              a.disabled(!is_answered(current)),
            ],
            [h.text("Neste runde")],
          ),
          h.button(
            [a.type_("button"), a.class("ghost"), e.on_click(ToggleWords)],
            [
              h.text(case current.reveal_words {
                True -> "Skjul ord"
                False -> "Vis ord"
              }),
            ],
          ),
        ]),
      ],
      case current.reveal_words {
        True -> [words_view(current)]
        False -> []
      },
      [
        h.form([a.class("answer-form"), e.on_submit(fn(_) { Submit })], [
          h.label([a.for("answer")], [h.text("Hvilke bokstaver hørte du?")]),
          h.input([
            a.id("answer"),
            a.type_("text"),
            a.value(current.answer),
            e.on_input(ChangeAnswer),
            a.placeholder("f.eks. AB"),
            a.attribute("autocomplete", "off"),
            a.spellcheck(False),
            a.disabled(is_answered(current)),
          ]),
          h.button([a.type_("submit"), a.disabled(is_answered(current))], [
            h.text("Sjekk svar"),
          ]),
        ]),
      ],
    ]),
  )
}

fn words_view(current: Round) -> Element(Message) {
  h.p(
    [a.class("round-words"), a.attribute("aria-label", "Ord i runden")],
    case current.outcome {
      AwaitingAnswer ->
        list.map(current.entries, fn(entry) {
          h.span([a.class("round-word")], [h.text(entry.word)])
        })
      Answered(results) ->
        list.map(results, fn(result) {
          h.span([a.class("round-word " <> result_class(result.correct))], [
            h.text(result.word),
          ])
        })
    },
  )
}

fn result_class(correct: Bool) -> String {
  case correct {
    True -> "correct"
    False -> "wrong"
  }
}

fn history_view(history: List(HistoryEntry)) -> Element(Message) {
  let results = list.flat_map(history, fn(entry) { entry.letters })
  let total = list.length(results)
  let correct = count_correct(results)
  let percent = case total {
    0 -> 0
    _ -> float.round(int.to_float(correct) /. int.to_float(total) *. 100.0)
  }
  h.aside(
    [a.class("history-panel"), a.attribute("aria-label", "Rundehistorikk")],
    [
      h.h2([], [h.text("Runder")]),
      h.p([a.class("history-summary")], [
        h.text(
          "Oppsummering: "
          <> int.to_string(correct)
          <> "/"
          <> int.to_string(total)
          <> " riktige bokstaver ("
          <> int.to_string(percent)
          <> "%)",
        ),
      ]),
      case history {
        [] -> h.p([a.class("history-empty")], [h.text("Ingen runder enda.")])
        _ ->
          h.div(
            [a.class("history-list")],
            list.map(history, history_entry_view),
          )
      },
    ],
  )
}

fn history_entry_view(entry: HistoryEntry) -> Element(Message) {
  h.div([a.class("history-item")], [
    h.p([a.class("history-round")], [
      h.text(
        "Runde "
        <> int.to_string(entry.number)
        <> " — "
        <> int.to_string(count_correct(entry.letters))
        <> "/"
        <> int.to_string(list.length(entry.letters)),
      ),
    ]),
    h.div(
      [a.class("history-letters")],
      list.map(entry.letters, fn(letter) {
        h.span([a.class("submitted-letter " <> result_class(letter.correct))], [
          h.text(letter.user),
        ])
      }),
    ),
  ])
}

fn numbers(first: Int, last: Int) -> List(Int) {
  case first > last {
    True -> []
    False -> [first, ..numbers(first + 1, last)]
  }
}
