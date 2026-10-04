import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event
import projects.{type Category, type Id, type Project, Active, Art, Play, Tools}

pub type Filter {
  All
  Category(Category)
}

pub type Playback {
  Playing
  Paused
}

pub type Model {
  Model(filter: Filter, playback: Playback, reduced_motion: Bool)
}

pub type Message {
  FilterBy(Filter)
  Toggle
  NewPattern
  PreviewChanged(reduced_motion: Bool, playing: Bool)
  Surprise(Option(Id))
  Picked(Id)
}

pub fn init() -> Model {
  Model(All, Paused, False)
}

pub fn mount() -> Effect(Message) {
  effect.from(fn(dispatch) {
    mount_preview(fn(reduced, playing) {
      dispatch(PreviewChanged(reduced, playing))
    })
  })
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    FilterBy(filter) -> #(Model(..model, filter: filter), effect.none())
    Toggle -> {
      let playing = model.playback == Paused
      let playback = case playing {
        True -> Playing
        False -> Paused
      }
      #(
        Model(..model, playback: playback),
        effect.from(fn(_) { set_playing(playing) }),
      )
    }
    NewPattern -> #(model, effect.from(fn(_) { new_pattern() }))
    PreviewChanged(reduced, playing) -> {
      let playback = case playing {
        True -> Playing
        False -> Paused
      }
      #(
        Model(..model, reduced_motion: reduced, playback: playback),
        effect.none(),
      )
    }
    Surprise(excluded) -> {
      let candidates = projects.surprise_candidates(excluded)
      #(
        model,
        effect.from(fn(dispatch) {
          case
            list.first(list.drop(
              candidates,
              random_index(list.length(candidates)),
            ))
          {
            Ok(project) -> dispatch(Picked(project.id))
            Error(_) -> Nil
          }
        }),
      )
    }
    Picked(id) -> #(model, effect.from(fn(_) { navigate(projects.href(id)) }))
  }
}

fn surprise(excluded: Option(Id)) -> Element(Message) {
  html.button(
    [
      attr.class("surprise"),
      attr.type_("button"),
      event.on_click(Surprise(excluded)),
    ],
    [text("Overrask meg")],
  )
}

fn card(project: Project) -> Element(message) {
  html.a(
    [attr.class("project-card card"), attr.href(projects.href(project.id))],
    [
      html.img([
        attr.src("/previews/" <> projects.slug(project.id) <> ".svg"),
        attr.width(360),
        attr.height(160),
        attr.alt(""),
        attr.attribute("aria-hidden", "true"),
      ]),
      html.div([attr.class("body")], [
        html.div([attr.class("meta")], [
          html.span([], [text(projects.category_label(project.category))]),
          case project.status {
            Active -> text("")
            _ -> html.span([attr.class("status")], [text("Under arbeid")])
          },
        ]),
        html.h2([], [text(project.title)]),
        html.p([], [text(project.hook)]),
        html.div([attr.class("foot")], [
          html.span([], [text(project.interaction)]),
          html.span(
            [attr.class("arrow"), attr.attribute("aria-hidden", "true")],
            [text("↗")],
          ),
        ]),
      ]),
    ],
  )
}

pub fn view_home(model: Model) -> Element(Message) {
  html.div([attr.class("home-page")], [
    html.section(
      [
        attr.class("hero terminal-panel"),
        attr.attribute("aria-labelledby", "home-title"),
      ],
      [
        html.div([attr.class("intro")], [
          html.p([attr.class("prompt")], [text("$ ./ulik --utforsk")]),
          html.h1([attr.id("home-title")], [
            html.span([attr.attribute("aria-hidden", "true")], [text("≠")]),
            text(" ulik.no"),
          ]),
          html.p([attr.class("tagline")], [text("ulik alt annet.")]),
          html.p([attr.class("description")], [
            text("Små eksperimenter. Rare ideer."),
            html.br([]),
            text("Ting du kan prøve, ikke bare lese om."),
          ]),
          html.div([attr.class("actions")], [
            html.a([attr.class("primary"), attr.href("/projects/flyt-felt")], [
              text("Lek med flyt≠felt "),
              html.span([attr.attribute("aria-hidden", "true")], [text("→")]),
            ]),
            surprise(None),
          ]),
          html.a([attr.class("catalog"), attr.href("/projects")], [
            text("Se alle 9 prosjekter ↓"),
          ]),
        ]),
        html.div([attr.class("home-preview")], [
          html.div([attr.class("preview")], [
            html.div([attr.class("preview-head")], [
              html.span([], [text("01 / flyt≠felt")]),
              html.span([], [text("prøv her ↓")]),
            ]),
            html.div([attr.class("art")], [
              html.img([
                attr.class("fallback"),
                attr.src("/previews/flyt-felt.svg"),
                attr.alt(""),
              ]),
              html.canvas([
                attr.id("home-flow"),
                attr.class("ready"),
                attr.attribute(
                  "aria-label",
                  "Forhåndsvisning av flyt≠felt: fargede spor som følger et strømningsfelt",
                ),
              ]),
            ]),
            html.div([attr.class("preview-foot")], [
              html.p([], [
                text(case model.reduced_motion {
                  True -> "Et stille mønster. Start bevegelsen hvis du vil."
                  False -> "Beveg pekeren eller berør bildet."
                }),
              ]),
              html.div([attr.class("controls")], [
                html.button(
                  [
                    attr.type_("button"),
                    event.on_click(Toggle),
                    attr.attribute(
                      "aria-pressed",
                      bool_string(model.playback == Playing),
                    ),
                  ],
                  [
                    text(case model.playback {
                      Playing -> "Pause bevegelse"
                      Paused -> "Start bevegelse"
                    }),
                  ],
                ),
                html.button([attr.type_("button"), event.on_click(NewPattern)], [
                  text("Nytt mønster"),
                ]),
              ]),
            ]),
          ]),
        ]),
      ],
    ),
    html.section(
      [
        attr.class("discovery"),
        attr.attribute("aria-labelledby", "discovery-title"),
      ],
      [
        html.div([attr.class("section-head")], [
          html.div([], [
            html.p([attr.class("prompt")], [text("$ ls ./muligheter")]),
            html.h2([attr.id("discovery-title")], [text("Hvor vil du begynne?")]),
          ]),
          html.a([attr.href("/projects")], [text("Hele katalogen →")]),
        ]),
        html.div(
          [attr.class("project-grid")],
          list.map([projects.Falling, projects.Morse, projects.Diff], fn(id) {
            card(projects.by_id(id))
          }),
        ),
        html.p([attr.class("note")], [text("Ingen konto. Bare nysgjerrighet.")]),
      ],
    ),
  ])
}

pub fn view_catalog(model: Model) -> Element(Message) {
  let visible =
    list.filter(projects.all(), fn(project) {
      model.filter == All || model.filter == Category(project.category)
    })
  html.div([attr.class("catalog-page")], [
    html.section([attr.class("terminal-panel page-head")], [
      html.p([attr.class("prompt")], [text("$ tree ./prosjekter -L 1")]),
      html.h1([], [text("Prosjekter")]),
      html.p([], [
        text(
          "Vil du leke, lage noe eller løse en liten floke? Velg et sidespor.",
        ),
      ]),
      html.div([], [surprise(None)]),
    ]),
    html.div(
      [
        attr.class("filters"),
        attr.attribute("role", "group"),
        attr.attribute("aria-label", "Filtrer prosjekter"),
      ],
      list.map(
        [All, Category(Play), Category(Art), Category(Tools)],
        fn(choice) {
          html.button(
            [
              attr.type_("button"),
              attr.attribute(
                "aria-pressed",
                bool_string(choice == model.filter),
              ),
              event.on_click(FilterBy(choice)),
            ],
            [
              text(case choice {
                All -> "Alle"
                Category(category) -> projects.category_label(category)
              }),
            ],
          )
        },
      ),
    ),
    html.p([attr.class("count"), attr.attribute("role", "status")], [
      text(
        "Viser " <> int.to_string(list.length(visible)) <> " av 9 prosjekter",
      ),
    ]),
    html.section(
      [attr.class("project-grid"), attr.attribute("aria-label", "Prosjekter")],
      list.map(visible, card),
    ),
  ])
}

pub fn onward(current: Id) -> Element(Message) {
  let #(related, different) = projects.onward(current)
  html.nav(
    [
      attr.class("onward-wrapper onward terminal-panel"),
      attr.attribute("aria-label", "Utforsk videre"),
    ],
    [
      html.div([attr.class("head")], [
        html.div([], [
          html.p([attr.class("prompt")], [text("$ cd ../neste")]),
          html.h2([], [text("Prøv noe mer")]),
        ]),
        html.a([attr.class("catalog"), attr.href("/projects")], [
          text("Alle prosjekter →"),
        ]),
      ]),
      html.div([attr.class("choices")], [
        suggestion("I samme spor", related),
        suggestion("Noe helt annet", different),
      ]),
      html.div([], [surprise(Some(current))]),
    ],
  )
}

fn suggestion(label: String, project: Option(Project)) -> Element(message) {
  case project {
    None -> text("")
    Some(project) ->
      html.a([attr.class("suggestion"), attr.href(projects.href(project.id))], [
        html.span([], [text(label)]),
        html.strong([], [text(project.title <> " ↗")]),
        html.span([], [text(project.hook)]),
      ])
  }
}

fn bool_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

@external(javascript, "./discovery_ffi.mjs", "mountPreview")
fn mount_preview(on_state: fn(Bool, Bool) -> Nil) -> Nil

@external(javascript, "./discovery_ffi.mjs", "setPlaying")
fn set_playing(playing: Bool) -> Nil

@external(javascript, "./discovery_ffi.mjs", "newPattern")
fn new_pattern() -> Nil

@external(javascript, "./discovery_ffi.mjs", "randomIndex")
fn random_index(length: Int) -> Int

@external(javascript, "./discovery_ffi.mjs", "navigate")
fn navigate(href: String) -> Nil

@external(javascript, "./discovery_ffi.mjs", "dispose")
pub fn dispose() -> Nil
