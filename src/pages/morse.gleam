import gleam/dynamic/decode
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

pub type Mode {
  Overview
  Receive
  Send
}

pub type Game {
  NotStarted
  ChoosingTarget
  Practicing(Round)
}

pub type Round {
  Round(target: String, answer: String, buffer: String, result: RoundResult)
}

pub type RoundResult {
  AwaitingAnswer
  Answered(String)
}

pub type Playback {
  Silent
  Playing(request: Int, letter: String, light_on: Bool)
}

pub type Key {
  Released
  Pressed(Float)
}

pub type HistoryEntry {
  HistoryEntry(mode: Mode, target: String, answer: String, correct: Bool)
}

pub type Model {
  Model(
    mode: Mode,
    wpm: Int,
    game: Game,
    playback: Playback,
    next_request: Int,
    key: Key,
    show_code: Bool,
    history: List(HistoryEntry),
    streak: Int,
  )
}

pub type Message {
  ChangeSpeed(String)
  PlayLetter(String)
  Replay
  StartRound
  TargetChosen(String)
  ChangeAnswer(String)
  Submit
  ToggleCode
  PressKey(Float)
  ReleaseKey(Float)
  AddSymbol(String)
  Backspace
  ClearBuffer
  Signal(Int, Bool)
  PlaybackDone(Int)
  NoOp
}

pub fn init(subpage: String) -> Model {
  Model(
    mode_from_string(subpage),
    15,
    NotStarted,
    Silent,
    1,
    Released,
    False,
    [],
    0,
  )
}

pub fn mount(subpage: String) -> Effect(Message) {
  effect.from(fn(dispatch) {
    init_morse(mode_from_string(subpage) == Overview, fn(key) {
      dispatch(PlayLetter(string.uppercase(key)))
    })
  })
}

@external(javascript, "../audio_ffi.mjs", "dispose")
pub fn dispose() -> Nil

@external(javascript, "../audio_ffi.mjs", "init_morse")
fn init_morse(overview: Bool, on_key: fn(String) -> Nil) -> Nil

@external(javascript, "../audio_ffi.mjs", "play_morse")
fn play_morse(
  request: Int,
  durations: List(Float),
  gap: Float,
  on_signal: fn(Int, Bool) -> Nil,
  on_done: fn(Int) -> Nil,
) -> Nil

@external(javascript, "../audio_ffi.mjs", "stop_morse")
fn stop_morse() -> Nil

@external(javascript, "../audio_ffi.mjs", "unlock_audio")
fn unlock_audio() -> Nil

@external(javascript, "../audio_ffi.mjs", "random_between")
fn random_between(minimum: Int, maximum: Int) -> Int

pub fn mode_from_string(subpage: String) -> Mode {
  case subpage {
    "motta" -> Receive
    "sende" -> Send
    _ -> Overview
  }
}

pub fn mode_name(mode: Mode) -> String {
  case mode {
    Overview -> "oversikt"
    Receive -> "motta"
    Send -> "sende"
  }
}

// Numeric keys are first to preserve the original overview order.
pub const alphabet: List(#(String, String)) = [
  #("0", "-----"),
  #("1", ".----"),
  #("2", "..---"),
  #("3", "...--"),
  #("4", "....-"),
  #("5", "....."),
  #("6", "-...."),
  #("7", "--..."),
  #("8", "---.."),
  #("9", "----."),
  #("A", ".-"),
  #("B", "-..."),
  #("C", "-.-."),
  #("D", "-.."),
  #("E", "."),
  #("F", "..-."),
  #("G", "--."),
  #("H", "...."),
  #("I", ".."),
  #("J", ".---"),
  #("K", "-.-"),
  #("L", ".-.."),
  #("M", "--"),
  #("N", "-."),
  #("O", "---"),
  #("P", ".--."),
  #("Q", "--.-"),
  #("R", ".-."),
  #("S", "..."),
  #("T", "-"),
  #("U", "..-"),
  #("V", "...-"),
  #("W", ".--"),
  #("X", "-..-"),
  #("Y", "-.--"),
  #("Z", "--.."),
]

pub fn morse_code(letter: String) -> String {
  alphabet
  |> list.find(fn(pair) { pair.0 == letter })
  |> result.map(fn(pair) { pair.1 })
  |> result.unwrap("")
}

pub fn decode_morse(code: String) -> Result(String, Nil) {
  alphabet
  |> list.find(fn(pair) { pair.1 == code })
  |> result.map(fn(pair) { pair.0 })
}

pub fn format_morse(code: String) -> String {
  code |> string.replace(".", "·") |> string.replace("-", "—")
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    ChangeSpeed(speed) -> #(
      Model(
        ..model,
        wpm: speed |> int.parse |> result.unwrap(model.wpm) |> int.clamp(5, 30),
      ),
      effect.none(),
    )
    PlayLetter(letter) ->
      case model.mode {
        Overview -> play(letter, model)
        _ -> #(model, effect.none())
      }
    Replay ->
      case model.game {
        Practicing(round) -> play(round.target, model)
        _ -> #(model, effect.none())
      }
    StartRound ->
      case model.mode == Overview || model.game == ChoosingTarget {
        True -> #(model, effect.none())
        False -> #(
          Model(..model, game: ChoosingTarget, key: Released, playback: Silent),
          effect.from(fn(dispatch) {
            stop_morse()
            unlock_audio()
            let target =
              alphabet
              |> list.drop(random_between(0, 35))
              |> list.first
              |> result.map(fn(entry) { entry.0 })
              |> result.unwrap("0")
            dispatch(TargetChosen(target))
          }),
        )
      }
    TargetChosen(target) -> {
      let next =
        Model(..model, game: Practicing(Round(target, "", "", AwaitingAnswer)))
      case model.mode {
        Receive -> play(target, next)
        _ -> #(next, effect.none())
      }
    }
    ChangeAnswer(answer) -> #(
      map_round(model, fn(round) { Round(..round, answer: answer) }),
      effect.none(),
    )
    Submit -> submit(model)
    ToggleCode -> #(Model(..model, show_code: !model.show_code), effect.none())
    PressKey(timestamp) ->
      case can_send(model) && model.key == Released {
        True -> #(Model(..model, key: Pressed(timestamp)), unlock())
        False -> #(model, effect.none())
      }
    ReleaseKey(timestamp) ->
      case model.key {
        Released -> #(model, effect.none())
        Pressed(started) -> {
          let duration = timestamp -. started
          let released = Model(..model, key: Released)
          case duration <. 40.0 {
            True -> #(released, effect.none())
            False ->
              update(
                released,
                AddSymbol(case duration <. 250.0 {
                  True -> "."
                  False -> "-"
                }),
              )
          }
        }
      }
    AddSymbol(symbol) ->
      case can_send(model) {
        True -> #(
          map_round(model, fn(round) {
            Round(..round, buffer: round.buffer <> symbol)
          }),
          unlock(),
        )
        False -> #(model, effect.none())
      }
    Backspace -> #(
      map_round(model, fn(round) {
        Round(..round, buffer: string.drop_end(round.buffer, 1))
      }),
      effect.none(),
    )
    ClearBuffer -> #(
      map_round(model, fn(round) { Round(..round, buffer: "") }),
      effect.none(),
    )
    Signal(request, light) ->
      case model.playback {
        Playing(current, letter, _) if request == current -> #(
          Model(..model, playback: Playing(current, letter, light)),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    PlaybackDone(request) ->
      case model.playback {
        Playing(current, _, _) if request == current -> #(
          Model(..model, playback: Silent),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    NoOp -> #(model, effect.none())
  }
}

fn unlock() -> Effect(Message) {
  effect.from(fn(_) { unlock_audio() })
}

pub fn can_send(model: Model) -> Bool {
  case model.game {
    Practicing(round) -> model.mode == Send && round.result == AwaitingAnswer
    _ -> False
  }
}

fn map_round(model: Model, transform: fn(Round) -> Round) -> Model {
  case model.game {
    Practicing(round) if round.result == AwaitingAnswer ->
      Model(..model, game: Practicing(transform(round)))
    _ -> model
  }
}

pub fn signal_durations(letter: String, wpm: Int) -> List(Float) {
  morse_code(letter)
  |> string.to_graphemes
  |> list.map(fn(symbol) {
    let units = case symbol {
      "-" -> 3.0
      _ -> 1.0
    }
    units *. 1200.0 /. int.to_float(wpm)
  })
}

fn play(letter: String, model: Model) -> #(Model, Effect(Message)) {
  case model.playback != Silent || morse_code(letter) == "" {
    True -> #(model, effect.none())
    False -> #(
      Model(
        ..model,
        playback: Playing(model.next_request, letter, False),
        next_request: model.next_request + 1,
      ),
      effect.from(fn(dispatch) {
        play_morse(
          model.next_request,
          signal_durations(letter, model.wpm),
          1200.0 /. int.to_float(model.wpm),
          fn(request, light) { dispatch(Signal(request, light)) },
          fn(request) { dispatch(PlaybackDone(request)) },
        )
      }),
    )
  }
}

fn submit(model: Model) -> #(Model, Effect(Message)) {
  case model.game {
    Practicing(round) ->
      case
        round.result != AwaitingAnswer
        || { model.mode == Send && round.buffer == "" }
      {
        True -> #(model, effect.none())
        False -> {
          let code = format_morse(morse_code(round.target))
          let decoded = decode_morse(round.buffer)
          let answer = case model.mode {
            Receive ->
              case round.answer |> string.trim |> string.uppercase {
                "" -> "∅"
                normalized -> normalized
              }
            _ -> result.unwrap(decoded, round.buffer)
          }
          let correct = answer == round.target
          let feedback = case model.mode, correct {
            Receive, True -> "Riktig! " <> round.target <> " er " <> code <> "."
            Receive, False ->
              "Det var "
              <> round.target
              <> " ("
              <> code
              <> "). Du svarte "
              <> answer
              <> "."
            _, True -> "Riktig! " <> code <> " = " <> round.target <> "."
            _, False ->
              case decoded {
                Ok(letter) ->
                  "Du sendte "
                  <> format_morse(round.buffer)
                  <> " = "
                  <> letter
                  <> ", men det skulle være "
                  <> code
                  <> " = "
                  <> round.target
                  <> "."
                Error(_) ->
                  format_morse(round.buffer)
                  <> " er ikke en gyldig morsekode. Riktig svar er "
                  <> code
                  <> " = "
                  <> round.target
                  <> "."
              }
          }
          #(
            Model(
              ..model,
              game: Practicing(Round(..round, result: Answered(feedback))),
              history: [
                HistoryEntry(model.mode, round.target, answer, correct),
                ..model.history
              ],
              streak: case correct {
                True -> model.streak + 1
                False -> 0
              },
              key: Released,
            ),
            effect.none(),
          )
        }
      }
    _ -> #(model, effect.none())
  }
}

pub fn view(model: Model) -> Element(Message) {
  h.div([a.class("morse-page")], [
    h.section([a.class("terminal-panel head")], [
      h.p([a.class("prompt")], [
        h.text("$ ./morse --subpage " <> mode_name(model.mode)),
      ]),
      h.div([a.class("head-row")], [
        h.h1([], [h.text("morse≠kode")]),
        h.span([a.class("status active")], [h.text("aktiv")]),
      ]),
      h.p([a.class("desc")], [
        h.text(
          "Øv deg på å sende og motta morsekode. Trykk start, lytt, se lyset og bruk mellomromstasten som nøkkel.",
        ),
      ]),
      h.div(
        [
          a.class("subpage-group"),
          a.attribute("role", "group"),
          a.attribute("aria-label", "Velg modus"),
        ],
        list.map([Overview, Receive, Send], mode_link(model.mode, _)),
      ),
    ]),
    h.section(
      [
        a.class("terminal-panel game"),
        a.attribute("aria-label", "Morsekode-øving"),
      ],
      [
        h.div([a.class("settings")], [
          h.label([a.for("wpm")], [h.text("Hastighet (ord per minutt)")]),
          h.input([
            a.id("wpm"),
            a.type_("range"),
            a.attribute("min", "5"),
            a.attribute("max", "30"),
            a.value(int.to_string(model.wpm)),
            e.on_input(ChangeSpeed),
          ]),
          h.span([a.class("wpm-value")], [
            h.text(int.to_string(model.wpm) <> " WPM"),
          ]),
        ]),
        ..game_view(model)
      ],
    ),
    history_view(model.history),
  ])
}

fn mode_link(selected: Mode, mode: Mode) -> Element(Message) {
  h.a(
    list.append(
      [
        a.href("/projects/morsekode/" <> mode_name(mode)),
        a.class(case selected == mode {
          True -> "active"
          False -> ""
        }),
      ],
      case selected == mode {
        True -> [a.attribute("aria-current", "page")]
        False -> []
      },
    ),
    [h.text(mode_name(mode))],
  )
}

fn game_view(model: Model) -> List(Element(Message)) {
  case model.mode {
    Overview -> [
      h.p([a.class("hint")], [
        h.text(
          "Trykk på en bokstav, eller trykk samme bokstav på tastaturet, for å høre og se koden.",
        ),
      ]),
      h.div(
        [a.class("letter-grid")],
        list.map(alphabet, letter_view(model.playback, _)),
      ),
      h.div([a.class("signal-preview")], [
        signal_light(model.playback, True, NoOp, "Forhåndsvisning av blink"),
      ]),
    ]
    _ ->
      case model.game {
        NotStarted -> [
          h.div([a.class("start-area")], [
            h.p([a.class("hint")], [
              h.text("Trykk start for å få en bokstav eller et tall."),
            ]),
            h.button(
              [a.type_("button"), a.class("primary"), e.on_click(StartRound)],
              [h.text("Start øving")],
            ),
          ]),
        ]
        ChoosingTarget -> [
          h.p([a.class("hint"), a.attribute("aria-live", "polite")], [
            h.text("Gjør klar neste runde…"),
          ]),
        ]
        Practicing(round) ->
          list.flatten([
            [target_view(model, round)],
            case round.result {
              Answered(feedback) -> [
                h.div([a.class("form-actions")], [
                  h.button(
                    [
                      a.type_("button"),
                      a.class("primary"),
                      e.on_click(StartRound),
                    ],
                    [h.text("Neste runde")],
                  ),
                ]),
                h.p([a.class("feedback"), a.attribute("aria-live", "polite")], [
                  h.text(feedback),
                ]),
              ]
              AwaitingAnswer ->
                case model.mode {
                  Receive -> [receive_form(round.answer)]
                  _ -> send_controls(model, round)
                }
            },
            [stats_view(model)],
          ])
      }
  }
}

fn letter_view(
  playback: Playback,
  entry: #(String, String),
) -> Element(Message) {
  let #(letter, code) = entry
  let active = case playback {
    Playing(_, current, _) -> current == letter
    Silent -> False
  }
  h.button(
    [
      a.type_("button"),
      a.class(case active {
        True -> "letter-tile playing"
        False -> "letter-tile"
      }),
      e.on_click(PlayLetter(letter)),
      a.disabled(playback != Silent),
      a.attribute("aria-label", letter <> ": " <> format_morse(code)),
    ],
    [
      h.span([a.class("letter-tile-char")], [h.text(letter)]),
      h.span([a.class("letter-tile-morse")], [h.text(format_morse(code))]),
    ],
  )
}

fn signal_light(
  playback: Playback,
  disabled: Bool,
  action: Message,
  description: String,
) -> Element(Message) {
  let light_on = case playback {
    Playing(_, _, light) -> light
    Silent -> False
  }
  h.button(
    [
      a.type_("button"),
      a.class(case light_on {
        True -> "signal-light active"
        False -> "signal-light"
      }),
      a.disabled(disabled),
      e.on_click(action),
      a.attribute("aria-label", description),
    ],
    [h.span([a.class("light-core")], []), h.span([a.class("light-glow")], [])],
  )
}

fn target_view(model: Model, round: Round) -> Element(Message) {
  h.div([a.class("target-area")], [
    h.span([a.class("target-label")], [
      h.text(case model.mode {
        Receive -> "Hva hører du?"
        _ -> "Send denne koden"
      }),
    ]),
    h.div(
      [a.class("target-card")],
      list.flatten([
        case model.mode {
          Send -> [
            h.span(
              [
                a.class("target-letter"),
                a.attribute("aria-label", "Målbokstav"),
              ],
              [h.text(round.target)],
            ),
          ]
          _ -> [
            signal_light(
              model.playback,
              model.playback != Silent,
              Replay,
              "Spill av morsekode",
            ),
            h.button(
              [
                a.type_("button"),
                a.class("small"),
                e.on_click(Replay),
                a.disabled(model.playback != Silent),
              ],
              [
                h.text(case model.playback {
                  Silent -> "spill av igjen"
                  _ -> "spiller…"
                }),
              ],
            ),
          ]
        },
        [
          h.button(
            [a.type_("button"), a.class("small"), e.on_click(ToggleCode)],
            [
              h.text(case model.show_code {
                True -> "skjul kode"
                False -> "vis kode"
              }),
            ],
          ),
        ],
        case model.show_code {
          True -> [
            h.p([a.class("morse-hint")], [
              h.text(format_morse(morse_code(round.target))),
            ]),
          ]
          False -> []
        },
      ]),
    ),
  ])
}

fn receive_form(answer: String) -> Element(Message) {
  h.form([a.class("answer-form"), e.on_submit(fn(_) { Submit })], [
    h.label([a.for("receive-answer")], [h.text("Bokstav eller tall")]),
    h.input([
      a.id("receive-answer"),
      a.type_("text"),
      a.value(answer),
      e.on_input(ChangeAnswer),
      a.placeholder("f.eks. A"),
      a.attribute("maxlength", "1"),
      a.attribute("autocomplete", "off"),
      a.spellcheck(False),
    ]),
    h.div([a.class("form-actions")], [
      h.button([a.type_("submit")], [h.text("Sjekk svar")]),
    ]),
  ])
}

fn send_controls(model: Model, round: Round) -> List(Element(Message)) {
  [
    h.div(
      [
        a.class(case model.key {
          Released -> "key-area"
          _ -> "key-area pressed"
        }),
        a.attribute("role", "button"),
        a.tabindex(0),
        a.attribute("aria-label", "Morsenøkkel. Hold for prikk eller strek."),
        e.on("pointerdown", timestamp_decoder(PressKey)),
        e.on("pointerup", timestamp_decoder(ReleaseKey)),
        e.on("pointerleave", timestamp_decoder(ReleaseKey)),
        e.on("pointercancel", timestamp_decoder(ReleaseKey)),
        e.on("blur", timestamp_decoder(ReleaseKey)),
        e.advanced("keydown", key_down_decoder()),
        e.advanced("keyup", key_up_decoder()),
      ],
      [
        h.span([a.class("key-label")], [h.text("Trykk og hold")]),
        h.span([a.class("key-hint")], [h.text("kort = prikk, lang = strek")]),
      ],
    ),
    h.div([a.class("manual-controls")], [
      h.button(
        [
          a.type_("button"),
          e.on_click(AddSymbol(".")),
          a.attribute("aria-label", "Legg til prikk"),
        ],
        [h.text("·")],
      ),
      h.button(
        [
          a.type_("button"),
          e.on_click(AddSymbol("-")),
          a.attribute("aria-label", "Legg til strek"),
        ],
        [h.text("—")],
      ),
      h.button([a.type_("button"), a.class("ghost"), e.on_click(Backspace)], [
        h.text("slett"),
      ]),
      h.button([a.type_("button"), a.class("ghost"), e.on_click(ClearBuffer)], [
        h.text("tøm"),
      ]),
    ]),
    h.div(
      [a.class("send-buffer"), a.attribute("aria-live", "polite")],
      case round.buffer {
        "" -> [
          h.span([a.class("buffer-empty")], [
            h.text("trykk nøkkelen for å sende"),
          ]),
        ]
        _ -> [
          h.span([a.class("buffer-chars")], [h.text(format_morse(round.buffer))]),
          h.span([a.class("buffer-guess")], [
            h.text(
              decode_morse(round.buffer)
              |> result.map(fn(letter) { "= " <> letter })
              |> result.unwrap("…"),
            ),
          ]),
        ]
      },
    ),
    h.div([a.class("form-actions")], [
      h.button(
        [
          a.type_("button"),
          a.class("primary"),
          e.on_click(Submit),
          a.disabled(round.buffer == ""),
        ],
        [h.text("Sjekk sending")],
      ),
    ]),
  ]
}

fn timestamp_decoder(message: fn(Float) -> Message) -> decode.Decoder(Message) {
  use timestamp <- decode.field("timeStamp", decode.float)
  decode.success(message(timestamp))
}

fn key_down_decoder() -> decode.Decoder(e.Handler(Message)) {
  use code <- decode.field("code", decode.string)
  use repeat <- decode.field("repeat", decode.bool)
  use timestamp <- decode.field("timeStamp", decode.float)
  let message = case code == "Space" && !repeat {
    True -> PressKey(timestamp)
    False -> NoOp
  }
  decode.success(e.handler(message, code == "Space", False))
}

fn key_up_decoder() -> decode.Decoder(e.Handler(Message)) {
  use code <- decode.field("code", decode.string)
  use timestamp <- decode.field("timeStamp", decode.float)
  let message = case code {
    "Space" -> ReleaseKey(timestamp)
    _ -> NoOp
  }
  decode.success(e.handler(message, code == "Space", False))
}

fn stats_view(model: Model) -> Element(Message) {
  let total = list.length(model.history)
  let correct =
    model.history |> list.filter(fn(entry) { entry.correct }) |> list.length
  let accuracy = case total {
    0 -> 0
    _ -> float.round(int.to_float(correct) /. int.to_float(total) *. 100.0)
  }
  h.div(
    [a.class("stats")],
    list.map(
      [
        "riktige: " <> int.to_string(correct) <> "/" <> int.to_string(total),
        "presisjon: " <> int.to_string(accuracy) <> "%",
        "streak: " <> int.to_string(model.streak),
      ],
      fn(stat) { h.span([a.class("stat")], [h.text(stat)]) },
    ),
  )
}

fn history_view(history: List(HistoryEntry)) -> Element(Message) {
  h.section(
    [
      a.class("terminal-panel history"),
      a.attribute("aria-label", "Rundehistorikk"),
    ],
    [
      h.p([a.class("prompt")], [h.text("$ cat ./morse.log")]),
      h.h2([], [h.text("Siste runder")]),
      case history {
        [] -> h.p([a.class("empty")], [h.text("Ingen runder enda. Kom igjen!")])
        _ ->
          h.ul(
            [a.class("history-list")],
            list.map(history, fn(entry) {
              h.li(
                [
                  a.class(
                    "history-item "
                    <> case entry.correct {
                      True -> "correct"
                      False -> "wrong"
                    },
                  ),
                ],
                [
                  h.span([a.class("history-subpage")], [
                    h.text(mode_name(entry.mode)),
                  ]),
                  h.span([a.class("history-target")], [h.text(entry.target)]),
                  h.span([a.class("history-answer")], [h.text(entry.answer)]),
                  h.span([a.class("history-result")], [
                    h.text(case entry.correct {
                      True -> "✓"
                      False -> "✕"
                    }),
                  ]),
                ],
              )
            }),
          )
      },
    ],
  )
}
