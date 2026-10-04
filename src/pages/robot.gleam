import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{attribute, class, disabled, id, tabindex, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, p, section, span, strong}
import lustre/event

pub type Status {
  Starting
  Ready
  Failed(String)
}

pub type Model {
  Model(
    status: Status,
    running: Bool,
    reduced_motion: Bool,
    keys: List(String),
    touch_key: Option(String),
  )
}

pub type Message {
  KeyDown(String)
  KeyUp(String)
  TouchDown(String)
  TouchUp
  ToggleRunning
  Reset
  Started(Bool)
  MotionChanged(Bool)
  ClearKeys
  FailedToStart(String)
  NoOp
}

type Callbacks {
  Callbacks(
    on_ready: fn(Bool) -> Nil,
    on_motion: fn(Bool) -> Nil,
    on_clear_keys: fn() -> Nil,
    on_release_touch: fn() -> Nil,
    on_error: fn(String) -> Nil,
    on_key_down: fn(String) -> Nil,
    on_key_up: fn(String) -> Nil,
  )
}

@external(javascript, "../visual_ffi.mjs", "mountRobot")
fn mount_world(callbacks: Callbacks) -> Nil

@external(javascript, "../visual_ffi.mjs", "inputRobot")
fn input_world(keys: List(String)) -> Nil

@external(javascript, "../visual_ffi.mjs", "runRobot")
fn run_world(running: Bool) -> Nil

@external(javascript, "../visual_ffi.mjs", "resetRobot")
fn reset_world() -> Nil

pub fn init() -> Model {
  Model(Starting, False, False, [], None)
}

pub fn mount() -> Effect(Message) {
  effect.from(fn(dispatch) {
    mount_world(
      Callbacks(
        fn(reduced) { dispatch(Started(reduced)) },
        fn(reduced) { dispatch(MotionChanged(reduced)) },
        fn() { dispatch(ClearKeys) },
        fn() { dispatch(TouchUp) },
        fn(error) { dispatch(FailedToStart(error)) },
        fn(key) { dispatch(KeyDown(key)) },
        fn(key) { dispatch(KeyUp(key)) },
      ),
    )
  })
}

fn send_input(model: Model) -> Effect(Message) {
  effect.from(fn(_) {
    let keys = case model.touch_key {
      Some(key) -> [key, ..model.keys]
      None -> model.keys
    }
    input_world(keys)
  })
}

fn set_running(value: Bool) -> Effect(Message) {
  effect.from(fn(_) { run_world(value) })
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    KeyDown(key) ->
      case list.contains(model.keys, key) {
        True -> #(model, effect.none())
        False -> {
          let next = Model(..model, keys: [key, ..model.keys])
          #(next, send_input(next))
        }
      }
    KeyUp(key) -> {
      let next =
        Model(
          ..model,
          keys: list.filter(model.keys, fn(pressed) { pressed != key }),
        )
      #(next, send_input(next))
    }
    TouchDown(key) -> {
      let next = Model(..model, touch_key: Some(key))
      #(next, send_input(next))
    }
    TouchUp -> {
      let next = Model(..model, touch_key: None)
      #(next, send_input(next))
    }
    ToggleRunning -> {
      let next =
        Model(..model, running: !model.running, keys: [], touch_key: None)
      #(next, effect.batch([set_running(next.running), send_input(next)]))
    }
    Reset -> #(
      Model(..model, keys: [], touch_key: None),
      effect.from(fn(_) { reset_world() }),
    )
    Started(reduced) -> #(
      Model(..model, status: Ready, running: !reduced, reduced_motion: reduced),
      set_running(!reduced),
    )
    MotionChanged(reduced) -> #(
      Model(
        ..model,
        reduced_motion: reduced,
        running: model.running && !reduced,
      ),
      case reduced {
        True -> set_running(False)
        False -> effect.none()
      },
    )
    ClearKeys -> {
      let next = Model(..model, keys: [], touch_key: None)
      #(next, send_input(next))
    }
    FailedToStart(error) -> #(
      Model(..model, status: Failed(error), running: False),
      effect.none(),
    )
    NoOp -> #(model, effect.none())
  }
}

pub fn view(model: Model) -> Element(Message) {
  let ready = model.status == Ready
  let status = case model.status {
    Starting -> "starter"
    Ready ->
      case model.running {
        True -> "aktiv"
        False -> "på pause"
      }
    Failed(_) -> "utilgjengelig"
  }
  div([class("robot-page")], [
    section([class("terminal-panel head")], [
      p([class("prompt")], [text("$ ./robot-tohjul --simuler")]),
      div([class("head-row")], [
        h1([], [text("robot≠tohjul")]),
        span(
          [
            class(case ready && model.running {
              True -> "status active"
              False -> "status"
            }),
          ],
          [text(status)],
        ),
      ]),
      p([class("desc")], [
        text("Styr roboten med "),
        strong([], [text("WASD")]),
        text(
          " eller piltaster. Den kjører på to hjul i en liten 3D-verden med hindringer. Treffer den en boks, krasjer den, rister, velter bakover, spretter rundt og kjører videre i tilfeldig retning.",
        ),
      ]),
    ]),
    div(
      [
        class("world terminal-panel"),
        id("robot-world"),
        tabindex(0),
        attribute("role", "group"),
        attribute(
          "aria-label",
          "Robotens 3D-verden. Bruk WASD, piltaster eller knappene under for å kjøre.",
        ),
      ],
      [],
    ),
    div([class("robot-controls"), attribute("aria-label", "Styr roboten")], [
      button(
        [type_("button"), disabled(!ready), event.on_click(ToggleRunning)],
        [
          text(case model.running {
            True -> "pause"
            False -> "spill av"
          }),
        ],
      ),
      button([type_("button"), disabled(!ready), event.on_click(Reset)], [
        text("start på nytt"),
      ]),
      direction_button(model, "w", "↑", "Kjør framover (W)"),
      direction_button(model, "s", "↓", "Rygg (S)"),
      direction_button(model, "a", "←", "Sving til venstre (A)"),
      direction_button(model, "d", "→", "Sving til høyre (D)"),
    ]),
    case model.reduced_motion {
      True ->
        p([class("motion-note")], [
          text(
            "Redusert bevegelse er valgt. Verdenen starter stille; spill av når du vil.",
          ),
        ])
      False -> text("")
    },
    case model.status {
      Failed(error) ->
        p([class("error"), attribute("role", "status")], [text(error)])
      _ -> text("")
    },
  ])
}

fn direction_button(
  model: Model,
  key: String,
  glyph: String,
  description: String,
) -> Element(Message) {
  button(
    [
      type_("button"),
      class("direction"),
      disabled(!model.running),
      attribute("aria-label", description),
      attribute(
        "aria-pressed",
        case model.touch_key == Some(key) || list.contains(model.keys, key) {
          True -> "true"
          False -> "false"
        },
      ),
      event.on("pointerdown", decode.success(TouchDown(key)))
        |> event.prevent_default,
      event.on("pointerup", decode.success(TouchUp)),
      event.on("pointerleave", decode.success(TouchUp)),
      event.on("pointercancel", decode.success(TouchUp)),
      event.on_keydown(fn(pressed) {
        case pressed {
          " " | "Enter" -> TouchDown(key)
          _ -> NoOp
        }
      }),
      event.on_keyup(fn(_) { TouchUp }),
      event.on_blur(TouchUp),
    ],
    [text(glyph)],
  )
}
