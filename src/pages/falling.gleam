import gleam/int
import lustre/attribute.{attribute, class, disabled, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, p, section, span}
import lustre/event.{on_click}

pub type Phase {
  Dropping
  Settled
  Restored
}

pub type Model {
  Model(phase: Phase, clone_count: Int)
}

pub type Message {
  Drop
  Reset
  Counted(Int)
  Finished
}

type Callbacks {
  Callbacks(
    on_reset: fn() -> Nil,
    on_count: fn(Int) -> Nil,
    on_settled: fn() -> Nil,
  )
}

@external(javascript, "../visual_ffi.mjs", "dropFalling")
fn drop_elements(callbacks: Callbacks) -> Nil

@external(javascript, "../visual_ffi.mjs", "resetFalling")
fn reset_elements() -> Nil

pub fn init() -> Model {
  Model(Dropping, 0)
}

pub fn mount() -> Effect(Message) {
  effect.from(fn(dispatch) {
    drop_elements(
      Callbacks(
        fn() { dispatch(Reset) },
        fn(count) { dispatch(Counted(count)) },
        fn() { dispatch(Finished) },
      ),
    )
  })
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    Drop -> #(Model(..model, phase: Dropping), mount())
    Reset -> #(Model(Restored, 0), effect.from(fn(_) { reset_elements() }))
    Counted(count) -> #(Model(..model, clone_count: count), effect.none())
    Finished -> #(Model(..model, phase: Settled), effect.none())
  }
}

pub fn view(model: Model) -> Element(Message) {
  div([class("falling-page")], [
    section([class("terminal-panel head")], [
      p([class("prompt")], [text("$ ./fall-haug --slipp-alt")]),
      div([class("head-row")], [
        h1([], [text("fall≠ned")]),
        span([class("status active")], [text("aktiv")]),
      ]),
      p([class("desc")], [
        text(
          "Denne versjonen slipper de faktiske elementene på siden: logo, meny, seksjoner, footer, og denne info-boksen ned.",
        ),
      ]),
    ]),
    section([class("terminal-panel dock")], [
      div([class("controls")], [
        button(
          [type_("button"), disabled(model.phase == Dropping), on_click(Drop)],
          [
            text(case model.phase {
              Dropping -> "slipper…"
              _ -> "slipp alt igjen"
            }),
          ],
        ),
      ]),
      p([class("meta")], [
        text(case model.clone_count > 0 {
          True -> int.to_string(model.clone_count) <> " elementer sluppet."
          False -> "forbereder slipp..."
        }),
      ]),
    ]),
    div([class("reset-wrap"), attribute("data-no-fall", "")], [
      button([type_("button"), class("reset-fixed"), on_click(Reset)], [
        text("reset side"),
      ]),
    ]),
  ])
}
