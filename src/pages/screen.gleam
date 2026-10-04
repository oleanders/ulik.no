import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event

pub type ShareState {
  Idle
  Sharing
  Failed
}

pub type Model {
  Model(
    supported: Bool,
    share_state: ShareState,
    status_text: String,
    source_label: String,
    include_audio: Bool,
  )
}

pub type Message {
  Start
  Stop
  IncludeAudio(Bool)
  Support(Bool)
  Started(String)
  Stopped
  ShareFailed(String)
}

@external(javascript, "../tools_ffi.mjs", "supportsDisplayMedia")
fn supports_display_media() -> Bool

@external(javascript, "../tools_ffi.mjs", "startSharing")
fn start_sharing(
  audio: Bool,
  on_started: fn(String) -> Nil,
  on_stopped: fn() -> Nil,
  on_failed: fn(String) -> Nil,
) -> Nil

@external(javascript, "../tools_ffi.mjs", "stopSharing")
fn stop_sharing() -> Nil

pub fn init() -> Model {
  Model(
    supported: False,
    share_state: Idle,
    status_text: "Trykk start for å velge skjerm, vindu eller fane.",
    source_label: "Ingen aktiv kilde",
    include_audio: False,
  )
}

pub fn mount() -> Effect(Message) {
  effect.from(fn(dispatch) { dispatch(Support(supports_display_media())) })
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    Start ->
      case model.supported && model.share_state != Sharing {
        True -> #(
          Model(..model, share_state: Idle, source_label: "Ingen aktiv kilde"),
          effect.from(fn(dispatch) {
            start_sharing(
              model.include_audio,
              fn(label) { dispatch(Started(label)) },
              fn() { dispatch(Stopped) },
              fn(message) { dispatch(ShareFailed(message)) },
            )
          }),
        )
        False -> #(model, effect.none())
      }
    Stop -> #(
      Model(
        ..model,
        share_state: Idle,
        status_text: "Skjermdeling er stoppet.",
        source_label: "Ingen aktiv kilde",
      ),
      effect.from(fn(_) { stop_sharing() }),
    )
    IncludeAudio(include_audio) -> #(
      Model(..model, include_audio: include_audio),
      effect.none(),
    )
    Support(supported) -> #(Model(..model, supported: supported), effect.none())
    Started(source_label) -> #(
      Model(
        ..model,
        share_state: Sharing,
        status_text: "Skjermdeling er aktiv.",
        source_label: source_label,
      ),
      effect.none(),
    )
    Stopped -> #(
      Model(
        ..model,
        share_state: Idle,
        status_text: "Skjermdeling ble stoppet fra nettleseren.",
        source_label: "Ingen aktiv kilde",
      ),
      effect.none(),
    )
    ShareFailed(message) -> #(
      Model(
        ..model,
        share_state: Failed,
        status_text: message,
        source_label: "Ingen aktiv kilde",
      ),
      effect.none(),
    )
  }
}

fn state_class(state: ShareState) -> String {
  case state {
    Idle -> "idle"
    Sharing -> "sharing"
    Failed -> "error"
  }
}

pub fn view(model: Model) -> Element(Message) {
  let sharing = model.share_state == Sharing
  let state = state_class(model.share_state)
  html.div([attribute.class("screen-page")], [
    html.section([attribute.class("terminal-panel head")], [
      html.p([attribute.class("prompt")], [
        text("$ ./skjermdeling-lab --start"),
      ]),
      html.div([attribute.class("head-row")], [
        html.h1([], [text("skjerm≠deling")]),
        html.span([attribute.class("status " <> state)], [
          text(case sharing {
            True -> "aktiv"
            False -> "klar"
          }),
        ]),
      ]),
      html.p([attribute.class("description")], [
        text("En enkel testlab for skjermdeling i nettleseren med "),
        html.code([], [text("navigator.mediaDevices.getDisplayMedia")]),
        text("."),
      ]),
    ]),
    html.section([attribute.class("terminal-panel controls")], [
      html.p([attribute.class("prompt")], [text("$ getdisplaymedia --preview")]),
      html.div([attribute.class("actions")], [
        html.button(
          [
            attribute.type_("button"),
            event.on_click(Start),
            attribute.disabled(!model.supported || sharing),
          ],
          [text("Start skjermdeling")],
        ),
        html.button(
          [
            attribute.type_("button"),
            attribute.class("ghost"),
            event.on_click(Stop),
            attribute.disabled(!sharing),
          ],
          [text("Stopp")],
        ),
      ]),
      html.label([attribute.class("option")], [
        html.input([
          attribute.type_("checkbox"),
          attribute.checked(model.include_audio),
          event.on_check(IncludeAudio),
          attribute.disabled(sharing),
        ]),
        text("Del systemlyd hvis tilgjengelig"),
      ]),
      html.p(
        [
          attribute.class("status-line " <> state),
          attribute.role("status"),
        ],
        [text(model.status_text)],
      ),
      html.p([attribute.class("source")], [
        text("Kilde: " <> model.source_label),
      ]),
      html.div(
        [
          attribute.class("preview"),
          attribute.attribute("data-active", case sharing {
            True -> "true"
            False -> "false"
          }),
        ],
        [
          html.video(
            [
              attribute.id("screen-preview"),
              attribute.playsinline(True),
              attribute.muted(True),
              attribute.controls(sharing),
            ],
            [],
          ),
        ],
      ),
    ]),
  ])
}
