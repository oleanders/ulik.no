import gleam/bool
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import gleam/uri
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html as h
import lustre/event

pub type Preset {
  Nordlys
  Virvel
  Glod
}

pub type Playback {
  Starting
  Playing
  Paused
  Unavailable
}

pub type Control {
  Speed
  Density
  Attraction
  Hue
}

pub type Config {
  Config(
    preset: Preset,
    seed: Int,
    speed: Float,
    density: Int,
    attraction: Float,
    hue: Int,
  )
}

pub type Pointer {
  Pointer(x: Float, y: Float)
}

pub type Model {
  Model(
    config: Config,
    playback: Playback,
    reduced_motion: Bool,
    message: String,
    share_url: String,
    share_base: String,
    exporting: Bool,
    pointer: Pointer,
    keyboard_active: Bool,
  )
}

pub type Message {
  SelectPreset(Preset)
  ChangeControl(Control, String)
  TogglePlayback
  NewUniverse
  Restart
  Share
  SavePng
  SelectShare
  Key(String)
  LoadedUrl(String)
  Started(Bool)
  MotionChanged(Bool)
  PointerUsed
  SeedChanged(Int)
  Shared(String)
  Exported(String)
  Failed(String)
}

// The rendering boundary contains data and individually typed callbacks, never a
// stringly-typed action protocol. It cannot change Gleam's application model.
type RendererConfig {
  RendererConfig(
    preset: String,
    seed: Int,
    speed: Float,
    density: Int,
    attraction: Float,
    hue: Int,
  )
}

type Callbacks {
  Callbacks(
    on_ready: fn(Bool) -> Nil,
    on_motion: fn(Bool) -> Nil,
    on_pointer_used: fn() -> Nil,
    on_error: fn(String) -> Nil,
  )
}

@external(javascript, "../visual_ffi.mjs", "locationHref")
fn location_href() -> String

@external(javascript, "../visual_ffi.mjs", "mountFlow")
fn mount_renderer(config: RendererConfig, callbacks: Callbacks) -> Nil

@external(javascript, "../visual_ffi.mjs", "configureFlow")
fn configure_renderer(config: RendererConfig) -> Nil

@external(javascript, "../visual_ffi.mjs", "runFlow")
fn run_renderer(running: Bool) -> Nil

@external(javascript, "../visual_ffi.mjs", "restartFlow")
fn restart_renderer() -> Nil

@external(javascript, "../visual_ffi.mjs", "pointFlow")
fn point_renderer(x: Float, y: Float) -> Nil

@external(javascript, "../visual_ffi.mjs", "clearFlowPointer")
fn clear_pointer() -> Nil

@external(javascript, "../visual_ffi.mjs", "newFlowSeed")
fn new_seed(previous: Int) -> Int

@external(javascript, "../visual_ffi.mjs", "shareFlow")
fn share_url(url: String, callback: fn(String) -> Nil) -> Nil

@external(javascript, "../visual_ffi.mjs", "saveFlowPng")
fn save_png(filename: String, callback: fn(String) -> Nil) -> Nil

@external(javascript, "../visual_ffi.mjs", "selectFlowShare")
fn select_share() -> Nil

pub fn init() -> Model {
  Model(
    preset_config(Nordlys, 20_261_002),
    Starting,
    False,
    "",
    "",
    "/projects/flyt-felt",
    False,
    Pointer(0.5, 0.5),
    False,
  )
}

pub fn mount() -> Effect(Message) {
  effect.from(fn(dispatch) { dispatch(LoadedUrl(location_href())) })
}

pub fn preset_id(preset: Preset) -> String {
  case preset {
    Nordlys -> "nordlys"
    Virvel -> "virvel"
    Glod -> "glod"
  }
}

fn preset_name(preset: Preset) -> String {
  case preset {
    Nordlys -> "Nordlys"
    Virvel -> "Virvel"
    Glod -> "Glød"
  }
}

fn preset_description(preset: Preset) -> String {
  case preset {
    Nordlys -> "Rolige bånd i grønt og blått."
    Virvel -> "Kjølige strømmer rundt et stille sentrum."
    Glod -> "Varme, raske spor med mer uro."
  }
}

pub fn preset_config(preset: Preset, seed: Int) -> Config {
  case preset {
    Nordlys -> Config(preset, seed, 0.75, 900, -1.0, 145)
    Virvel -> Config(preset, seed, 1.0, 1200, 1.0, 195)
    Glod -> Config(preset, seed, 1.5, 600, -0.5, 5)
  }
}

fn renderer_config(config: Config) -> RendererConfig {
  RendererConfig(
    preset_id(config.preset),
    config.seed,
    config.speed,
    config.density,
    config.attraction,
    config.hue,
  )
}

fn limits(control: Control) -> #(Float, Float, Float) {
  case control {
    Speed -> #(0.25, 2.0, 0.05)
    Density -> #(300.0, 1500.0, 100.0)
    Attraction -> #(-2.0, 2.0, 0.1)
    Hue -> #(0.0, 359.0, 1.0)
  }
}

pub fn bounded_number(control: Control, number: Float) -> Float {
  let #(minimum, maximum, increment) = limits(control)
  let bounded = float.clamp(number, minimum, maximum)
  let steps = float.round({ bounded -. minimum } /. increment) |> int.to_float
  float.round({ minimum +. steps *. increment } *. 100.0)
  |> int.to_float
  |> fn(n) { n /. 100.0 }
}

fn valid_digits(maximum: Int, raw: String) -> Bool {
  raw != ""
  && string.length(raw) <= maximum
  && list.all(string.to_graphemes(raw), fn(char) {
    list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], char)
  })
}

pub fn valid_number(raw: String) -> Result(Float, Nil) {
  let unsigned = case string.starts_with(raw, "-") {
    True -> string.drop_start(raw, 1)
    False -> raw
  }
  let valid = case string.split(unsigned, ".") {
    [whole] -> valid_digits(10, whole)
    [whole, fraction] -> valid_digits(10, whole) && valid_digits(4, fraction)
    _ -> False
  }
  case valid {
    True ->
      case float.parse(raw) {
        Ok(number) -> Ok(number)
        Error(_) -> int.parse(raw) |> result.map(int.to_float)
      }
    False -> Error(Nil)
  }
}

/// Only a small, versioned configuration can cross from a URL to the renderer.
/// Decimal syntax excludes exponents, non-finite values and oversized inputs.
pub fn parse_config(query: String) -> Config {
  let pairs =
    list.map(string.split(query, "&"), fn(pair) {
      let parts = string.split(pair, "=")
      let key = list.first(parts) |> result.unwrap("")
      let value = list.drop(parts, 1) |> string.join("=")
      let decode_part = fn(raw) {
        uri.percent_decode(string.replace(raw, "+", " ")) |> result.unwrap(raw)
      }
      #(decode_part(key), decode_part(value))
    })
  let get = fn(key) { list.key_find(pairs, key) }
  let preset = case get("preset") {
    Ok("virvel") -> Virvel
    Ok("glod") -> Glod
    _ -> Nordlys
  }
  let defaults = preset_config(preset, 20_261_002)
  let number = fn(key, control, fallback) {
    get(key)
    |> result.try(valid_number)
    |> result.map(fn(n) { bounded_number(control, n) })
    |> result.unwrap(fallback)
  }
  let seed = case get("seed") {
    Ok(raw) ->
      case valid_digits(10, raw) {
        True ->
          case int.parse(raw) {
            Ok(n) if n >= 1 && n <= 4_294_967_295 -> n
            _ -> defaults.seed
          }
        False -> defaults.seed
      }
    Error(_) -> defaults.seed
  }
  case
    string.length(query) > 1000
    || { get("v") != Error(Nil) && get("v") != Ok("1") }
  {
    True -> preset_config(Nordlys, 20_261_002)
    False ->
      Config(
        preset,
        seed,
        number("speed", Speed, defaults.speed),
        float.round(number("density", Density, int.to_float(defaults.density))),
        number("attraction", Attraction, defaults.attraction),
        float.round(number("hue", Hue, int.to_float(defaults.hue))),
      )
  }
}

fn configure(model: Model, config: Config) -> #(Model, Effect(Message)) {
  #(
    Model(
      ..model,
      config: config,
      share_url: "",
      message: "",
      keyboard_active: False,
    ),
    effect.from(fn(_) { configure_renderer(renderer_config(config)) }),
  )
}

fn set_running(running: Bool) -> Effect(Message) {
  effect.from(fn(_) { run_renderer(running) })
}

fn available(model: Model) -> Bool {
  model.playback == Playing || model.playback == Paused
}

pub fn config_query(config: Config) -> String {
  uri.query_to_string([
    #("v", "1"),
    #("preset", preset_id(config.preset)),
    #("seed", int.to_string(config.seed)),
    #("speed", decimal(config.speed)),
    #("density", int.to_string(config.density)),
    #("attraction", decimal(config.attraction)),
    #("hue", int.to_string(config.hue)),
  ])
}

fn decimal(number: Float) -> String {
  case string.split(float.to_string(number), ".") {
    [whole, "0"] -> whole
    _ -> float.to_string(number)
  }
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    LoadedUrl(url_string) -> {
      let url = uri.parse(url_string) |> result.unwrap(uri.empty)
      let config = parse_config(option.unwrap(url.query, ""))
      let base = case url.host {
        None -> "/projects/flyt-felt"
        _ -> uri.to_string(uri.Uri(..url, query: None, fragment: None))
      }
      #(
        Model(..model, config: config, share_base: base),
        effect.from(fn(dispatch) {
          mount_renderer(
            renderer_config(config),
            Callbacks(
              fn(reduced) { dispatch(Started(reduced)) },
              fn(reduced) { dispatch(MotionChanged(reduced)) },
              fn() { dispatch(PointerUsed) },
              fn(error) { dispatch(Failed(error)) },
            ),
          )
        }),
      )
    }
    SelectPreset(preset) ->
      configure(model, preset_config(preset, model.config.seed))
    ChangeControl(control, raw) ->
      case valid_number(raw) {
        Error(_) -> #(model, effect.none())
        Ok(number) -> {
          let bounded = bounded_number(control, number)
          let config = model.config
          let next = case control {
            Speed -> Config(..config, speed: bounded)
            Density -> Config(..config, density: float.round(bounded))
            Attraction -> Config(..config, attraction: bounded)
            Hue -> Config(..config, hue: float.round(bounded))
          }
          configure(model, next)
        }
      }
    TogglePlayback ->
      case available(model) {
        False -> #(model, effect.none())
        True -> {
          let running = model.playback != Playing
          #(
            Model(..model, playback: case running {
              True -> Playing
              False -> Paused
            }),
            set_running(running),
          )
        }
      }
    NewUniverse -> #(
      model,
      effect.from(fn(dispatch) {
        dispatch(SeedChanged(new_seed(model.config.seed)))
      }),
    )
    Restart -> #(
      Model(
        ..model,
        pointer: Pointer(0.5, 0.5),
        keyboard_active: False,
        message: "Samme univers, tilbake til starten.",
      ),
      effect.from(fn(_) { restart_renderer() }),
    )
    Share -> {
      let url = model.share_base <> "?" <> config_query(model.config)
      #(
        Model(..model, share_url: url),
        effect.from(fn(dispatch) {
          share_url(url, fn(message) { dispatch(Shared(message)) })
        }),
      )
    }
    SavePng ->
      case model.exporting || !available(model) {
        True -> #(model, effect.none())
        False -> #(
          Model(..model, exporting: True),
          effect.from(fn(dispatch) {
            save_png(
              "flyt-felt-"
                <> preset_id(model.config.preset)
                <> "-"
                <> int.to_string(model.config.seed)
                <> ".png",
              fn(message) { dispatch(Exported(message)) },
            )
          }),
        )
      }
    SelectShare -> #(model, effect.from(fn(_) { select_share() }))
    Key(" ") -> update(model, TogglePlayback)
    Key("Escape") -> #(
      Model(..model, keyboard_active: False),
      effect.from(fn(_) { clear_pointer() }),
    )
    Key(key) -> {
      let #(dx, dy) = case key {
        "ArrowLeft" -> #(-0.05, 0.0)
        "ArrowRight" -> #(0.05, 0.0)
        "ArrowUp" -> #(0.0, -0.05)
        "ArrowDown" -> #(0.0, 0.05)
        _ -> #(0.0, 0.0)
      }
      let pointer =
        Pointer(
          float.clamp(model.pointer.x +. dx, 0.0, 1.0),
          float.clamp(model.pointer.y +. dy, 0.0, 1.0),
        )
      case dx == 0.0 && dy == 0.0 {
        True -> #(model, effect.none())
        False -> #(
          Model(..model, pointer: pointer, keyboard_active: True),
          effect.from(fn(_) { point_renderer(pointer.x, pointer.y) }),
        )
      }
    }
    Started(reduced) -> #(
      Model(
        ..model,
        playback: case reduced {
          True -> Paused
          False -> Playing
        },
        reduced_motion: reduced,
      ),
      set_running(!reduced),
    )
    MotionChanged(reduced) -> #(
      Model(..model, reduced_motion: reduced, playback: case reduced {
        True -> Paused
        False -> model.playback
      }),
      case reduced {
        True -> set_running(False)
        False -> effect.none()
      },
    )
    PointerUsed -> #(Model(..model, keyboard_active: False), effect.none())
    SeedChanged(seed) -> {
      let #(next, command) =
        configure(model, Config(..model.config, seed: seed))
      #(Model(..next, message: "Et nytt univers er klart."), command)
    }
    Shared(message) -> #(Model(..model, message: message), effect.none())
    Exported(message) -> #(
      Model(..model, exporting: False, message: message),
      effect.none(),
    )
    Failed(message) -> #(
      Model(..model, playback: Unavailable, message: message),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Message) {
  let ready = available(model)
  let running = model.playback == Playing
  let name = preset_name(model.config.preset)
  let status = case model.playback {
    Starting -> "starter"
    Playing -> "i bevegelse"
    Paused -> "på pause"
    Unavailable -> "utilgjengelig"
  }
  h.div([a.class("flow-page")], [
    h.section([a.class("head"), a.attribute("aria-labelledby", "flow-title")], [
      h.p([a.class("prompt")], [text("$ ./flyt-felt --utforsk")]),
      h.div([a.class("head-row")], [
        h.h1([a.id("flow-title")], [text("flyt≠felt")]),
        h.span(
          [
            a.class(case ready && running {
              True -> "status active"
              False -> "status"
            }),
          ],
          [text(status)],
        ),
      ]),
      h.p([a.class("desc")], [
        text(
          "Små partikler. Egne veier. Velg en stemning, form strømmen og ta vare på et øyeblikk.",
        ),
      ]),
    ]),
    h.section([a.class("studio"), a.attribute("aria-label", "Ditt flytfelt")], [
      h.div([a.class("canvas-wrap"), a.id("flow-wrapper")], [
        element.element(
          "canvas",
          [
            a.id("flow-canvas"),
            a.tabindex(0),
            a.attribute("aria-label", "Flytfelt: " <> name),
            a.attribute("aria-describedby", "flow-help"),
            canvas_keyboard(),
          ],
          [
            text(
              "Et generativt bilde av fargede partikler. Nettleseren må støtte canvas for å vise det.",
            ),
          ],
        ),
        case model.keyboard_active {
          True ->
            h.span(
              [
                a.class("keyboard-pointer"),
                a.attribute("aria-hidden", "true"),
                a.style("left", decimal(model.pointer.x *. 100.0) <> "%"),
                a.style("top", decimal(model.pointer.y *. 100.0) <> "%"),
              ],
              [],
            )
          False -> text("")
        },
      ]),
      h.div([a.class("canvas-footer")], [
        h.span([], [
          text(name <> " / seed "),
          h.span([a.attribute("data-testid", "flow-seed")], [
            text(int.to_string(model.config.seed)),
          ]),
        ]),
        h.span([], [
          text(
            int.to_string(model.config.density)
            <> " partikler · lokalt i nettleseren",
          ),
        ]),
      ]),
      h.div([a.class("toolbar")], [
        h.button(
          [
            a.type_("button"),
            a.class("primary"),
            a.disabled(!ready),
            event.on_click(TogglePlayback),
          ],
          [
            text(case running {
              True -> "pause"
              False -> "spill av"
            }),
          ],
        ),
        h.button(
          [a.type_("button"), a.disabled(!ready), event.on_click(NewUniverse)],
          [text("nytt univers")],
        ),
        h.button(
          [a.type_("button"), a.disabled(!ready), event.on_click(Restart)],
          [text("start på nytt")],
        ),
        h.button(
          [
            a.type_("button"),
            a.disabled(!ready || model.exporting),
            event.on_click(SavePng),
          ],
          [
            text(case model.exporting {
              True -> "lager bilde …"
              False -> "lagre PNG"
            }),
          ],
        ),
        h.button(
          [a.type_("button"), a.disabled(!ready), event.on_click(Share)],
          [text("del univers")],
        ),
      ]),
      h.p([a.class("help"), a.id("flow-help")], [
        text(
          "Beveg pekeren eller dra én finger over bildet. Med tastatur: fokuser bildet og bruk piltastene. Mellomrom pauser, Esc slipper feltet. Du kan rulle siden utenfor bildet.",
        ),
      ]),
      case model.reduced_motion {
        True ->
          h.p([a.class("motion-note")], [
            text(
              "Redusert bevegelse er valgt. Bildet starter stille; spill av når du vil.",
            ),
          ])
        False -> text("")
      },
    ]),
    h.section(
      [
        a.class("terminal-panel settings"),
        a.attribute("aria-label", "Innstillinger for flytfelt"),
      ],
      [
        h.fieldset([a.class("presets")], [
          h.legend([], [text("01 / velg en stemning")]),
          h.div(
            [a.class("preset-grid")],
            list.map([Nordlys, Virvel, Glod], preset_button(
              model.config.preset,
              _,
            )),
          ),
        ]),
        h.fieldset([a.class("adjustments")], [
          h.legend([], [text("02 / finn din flyt")]),
          h.div([a.class("slider-grid")], [
            slider(
              Speed,
              "flow-speed",
              "Fart",
              fixed(2, model.config.speed) <> "×",
              "rolig → rask",
              model.config.speed,
            ),
            slider(
              Density,
              "flow-density",
              "Tetthet",
              int.to_string(model.config.density),
              "luftig → tett",
              int.to_float(model.config.density),
            ),
            slider(
              Attraction,
              "flow-attraction",
              "Tiltrekning",
              fixed(1, model.config.attraction),
              "dytt ← 0 → trekk, ved pekeren",
              model.config.attraction,
            ),
            slider(
              Hue,
              "flow-hue",
              "Fargetone",
              int.to_string(model.config.hue) <> "°",
              "hele fargesirkelen",
              int.to_float(model.config.hue),
            ),
          ]),
        ]),
        h.div([a.class("settings-footer")], [
          h.p([], [
            text("Endringer tegner universet fra starten. Seedet beholdes."),
          ]),
          h.button(
            [
              a.type_("button"),
              event.on_click(SelectPreset(model.config.preset)),
            ],
            [text("nullstill innstillinger")],
          ),
        ]),
      ],
    ),
    h.div([a.class("sharing")], [
      h.p(
        [
          a.class("feedback"),
          a.attribute("role", "status"),
          a.attribute("aria-label", "Melding fra flytfelt"),
        ],
        [text(model.message)],
      ),
      ..case model.share_url {
        "" -> []
        _ -> [
          h.label([a.for("flow-share")], [text("Lenke til universet")]),
          h.input([
            a.id("flow-share"),
            a.type_("url"),
            a.readonly(True),
            a.value(model.share_url),
            event.on_click(SelectShare),
          ]),
          h.p([a.class("help")], [
            text(
              "Lenken inneholder bare innstillinger og seed. Bevegelsene dine og det ferdige bildet følger ikke med. Bruk PNG for å bevare akkurat dette øyeblikket.",
            ),
          ]),
        ]
      }
    ]),
  ])
}

fn preset_button(selected: Preset, preset: Preset) -> Element(Message) {
  h.button(
    [
      a.type_("button"),
      a.class("preset"),
      a.attribute("aria-pressed", bool.to_string(selected == preset)),
      event.on_click(SelectPreset(preset)),
    ],
    [
      h.span([a.class("preset-name")], [text(preset_name(preset))]),
      h.span([a.class("preset-description")], [text(preset_description(preset))]),
    ],
  )
}

fn slider(
  control: Control,
  input_id: String,
  title: String,
  formatted: String,
  hint: String,
  current: Float,
) -> Element(Message) {
  let #(minimum, maximum, increment) = limits(control)
  h.label([a.for(input_id)], [
    h.span([], [text(title), h.output([a.for(input_id)], [text(formatted)])]),
    h.input([
      a.id(input_id),
      a.type_("range"),
      a.min(decimal(minimum)),
      a.max(decimal(maximum)),
      a.step(decimal(increment)),
      a.value(decimal(current)),
      event.on_input(ChangeControl(control, _)),
    ]),
    h.small([], [text(hint)]),
  ])
}

pub fn fixed(places: Int, number: Float) -> String {
  let scale = case places {
    1 -> 10
    _ -> 100
  }
  let rounded = float.round(number *. int.to_float(scale)) |> int.absolute_value
  let whole = int.to_string(rounded / scale)
  let fraction = int.to_string(rounded % scale) |> string.pad_start(places, "0")
  let sign = case number <. 0.0 {
    True -> "-"
    False -> ""
  }
  sign <> whole <> "." <> fraction
}

fn canvas_keyboard() -> a.Attribute(Message) {
  let decoder = {
    use key <- decode.field("key", decode.string)
    decode.success(event.handler(
      Key(key),
      list.contains(
        [" ", "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"],
        key,
      ),
      False,
    ))
  }
  event.advanced("keydown", decoder)
}
