import deploy
import discovery
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/uri
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import pages/diff
import pages/falling
import pages/flow
import pages/illusions
import pages/morse
import pages/nato
import pages/robot
import pages/screen
import projects

pub type Route {
  Home
  Catalog
  About
  Project(projects.Id, String)
  NotFound
}

type Page {
  HomePage
  CatalogPage
  AboutPage
  PlaceholderPage
  NotFoundPage
  FlowPage(flow.Model)
  RobotPage(robot.Model)
  FallingPage(falling.Model)
  NatoPage(nato.Model)
  MorsePage(morse.Model)
  DiffPage(diff.Model)
  ScreenPage(screen.Model)
  IllusionsPage(illusions.Model)
}

type Model {
  Model(
    url: String,
    route: Route,
    page: Page,
    discovery: discovery.Model,
    deploy: deploy.Model,
    version: String,
    revision: Int,
  )
}

type PageMessage {
  FlowMessage(flow.Message)
  RobotMessage(robot.Message)
  FallingMessage(falling.Message)
  NatoMessage(nato.Message)
  MorseMessage(morse.Message)
  DiffMessage(diff.Message)
  ScreenMessage(screen.Message)
  IllusionsMessage(illusions.Message)
}

type Message {
  Navigated(String)
  Mounted(Int)
  DiscoveryMessage(discovery.Message)
  DeployMessage(deploy.Message)
  PageMessage(Int, PageMessage)
}

pub fn route_from_url(url: String) -> Route {
  let path = case uri.parse(url) {
    Ok(url) -> url.path
    Error(_) -> url
  }
  case string.split(path, "/") |> list.filter(fn(part) { part != "" }) {
    [] -> Home
    ["projects"] -> Catalog
    ["om"] -> About
    ["projects", "morsekode"] -> Project(projects.Morse, "oversikt")
    ["projects", "morsekode", subpage] ->
      case subpage {
        "oversikt" | "motta" | "sende" -> Project(projects.Morse, subpage)
        _ -> NotFound
      }
    ["projects", slug] ->
      case projects.from_slug(slug) {
        Some(id) -> Project(id, "")
        None -> NotFound
      }
    _ -> NotFound
  }
}

fn initial_page(route: Route) -> Page {
  case route {
    Home -> HomePage
    Catalog -> CatalogPage
    About -> AboutPage
    NotFound -> NotFoundPage
    Project(id, subpage) ->
      case id {
        projects.Prompt -> PlaceholderPage
        projects.Flow -> FlowPage(flow.init())
        projects.Robot -> RobotPage(robot.init())
        projects.Falling -> FallingPage(falling.init())
        projects.Nato -> NatoPage(nato.init())
        projects.Morse -> MorsePage(morse.init(subpage))
        projects.Diff -> DiffPage(diff.init())
        projects.Screen -> ScreenPage(screen.init())
        projects.Illusion -> IllusionsPage(illusions.init())
      }
  }
}

fn initial_model(url: String, version: String) -> Model {
  let route = route_from_url(url)
  Model(
    url,
    route,
    initial_page(route),
    discovery.init(),
    deploy.init(),
    version,
    0,
  )
}

pub fn start(url: String, version: String) -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", #(url, version))
  Nil
}

fn init(flags: #(String, String)) -> #(Model, Effect(Message)) {
  let model = initial_model(flags.0, flags.1)
  #(
    model,
    effect.batch([
      effect.from(fn(dispatch) { listen(fn(url) { dispatch(Navigated(url)) }) }),
      rendered(model),
      effect.map(deploy.mount(), DeployMessage),
    ]),
  )
}

fn rendered(model: Model) -> Effect(Message) {
  effect.from(fn(dispatch) {
    after_render(title(model.route), fn() { dispatch(Mounted(model.revision)) })
  })
}

fn mount_page(model: Model) -> Effect(Message) {
  let wrap = fn(message) { PageMessage(model.revision, message) }
  case model.page {
    HomePage -> effect.map(discovery.mount(), DiscoveryMessage)
    FlowPage(_) -> flow.mount() |> effect.map(FlowMessage) |> effect.map(wrap)
    RobotPage(_) ->
      robot.mount() |> effect.map(RobotMessage) |> effect.map(wrap)
    FallingPage(_) ->
      falling.mount() |> effect.map(FallingMessage) |> effect.map(wrap)
    NatoPage(_) -> nato.mount() |> effect.map(NatoMessage) |> effect.map(wrap)
    MorsePage(_) -> {
      let subpage = case model.route {
        Project(_, subpage) -> subpage
        _ -> "oversikt"
      }
      morse.mount(subpage) |> effect.map(MorseMessage) |> effect.map(wrap)
    }
    ScreenPage(_) ->
      screen.mount() |> effect.map(ScreenMessage) |> effect.map(wrap)
    IllusionsPage(_) ->
      illusions.mount() |> effect.map(IllusionsMessage) |> effect.map(wrap)
    _ -> effect.none()
  }
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    Navigated(url) if url == model.url -> #(model, effect.none())
    Navigated(url) -> {
      let route = route_from_url(url)
      let next =
        Model(
          ..model,
          url: url,
          route: route,
          page: initial_page(route),
          revision: model.revision + 1,
        )
      #(next, rendered(next))
    }
    Mounted(revision) if revision == model.revision -> #(
      model,
      mount_page(model),
    )
    Mounted(_) -> #(model, effect.none())
    DiscoveryMessage(message) -> {
      let #(state, effects) = discovery.update(model.discovery, message)
      #(Model(..model, discovery: state), effect.map(effects, DiscoveryMessage))
    }
    DeployMessage(message) -> {
      let #(state, effects) = deploy.update(model.deploy, message)
      #(Model(..model, deploy: state), effect.map(effects, DeployMessage))
    }
    PageMessage(revision, _) if revision != model.revision -> #(
      model,
      effect.none(),
    )
    PageMessage(_, message) -> update_page(model, message)
  }
}

fn update_page(
  model: Model,
  message: PageMessage,
) -> #(Model, Effect(Message)) {
  let #(page, effects) = case model.page, message {
    FlowPage(state), FlowMessage(message) -> {
      let #(state, effects) = flow.update(state, message)
      #(FlowPage(state), effect.map(effects, FlowMessage))
    }
    RobotPage(state), RobotMessage(message) -> {
      let #(state, effects) = robot.update(state, message)
      #(RobotPage(state), effect.map(effects, RobotMessage))
    }
    FallingPage(state), FallingMessage(message) -> {
      let #(state, effects) = falling.update(state, message)
      #(FallingPage(state), effect.map(effects, FallingMessage))
    }
    NatoPage(state), NatoMessage(message) -> {
      let #(state, effects) = nato.update(state, message)
      #(NatoPage(state), effect.map(effects, NatoMessage))
    }
    MorsePage(state), MorseMessage(message) -> {
      let #(state, effects) = morse.update(state, message)
      #(MorsePage(state), effect.map(effects, MorseMessage))
    }
    DiffPage(state), DiffMessage(message) -> {
      let #(state, effects) = diff.update(state, message)
      #(DiffPage(state), effect.map(effects, DiffMessage))
    }
    ScreenPage(state), ScreenMessage(message) -> {
      let #(state, effects) = screen.update(state, message)
      #(ScreenPage(state), effect.map(effects, ScreenMessage))
    }
    IllusionsPage(state), IllusionsMessage(message) -> {
      let #(state, effects) = illusions.update(state, message)
      #(IllusionsPage(state), effect.map(effects, IllusionsMessage))
    }
    _, _ -> #(model.page, effect.none())
  }
  #(
    Model(..model, page: page),
    effect.map(effects, fn(message) { PageMessage(model.revision, message) }),
  )
}

pub fn title(route: Route) -> String {
  case route {
    Home -> "≠ ulik.no — ulik alt annet"
    Catalog -> "Prosjekter — ≠ ulik.no"
    About -> "Om — ≠ ulik.no"
    Project(id, _) -> projects.by_id(id).title <> " — ≠ ulik.no"
    NotFound -> "Fant ikke siden — ≠ ulik.no"
  }
}

pub fn render(url: String, version: String) -> String {
  initial_model(url, version) |> view |> element.to_string
}

fn view(model: Model) -> Element(Message) {
  h.div([attr.class("layout")], [
    h.header([attr.class("shell-header")], [
      h.nav([attr.attribute("aria-label", "Hovednavigasjon")], [
        h.a(
          [
            attr.href("/"),
            attr.class("logo"),
            attr.attribute("aria-label", "ulik.no hjem"),
          ],
          [h.text("≠")],
        ),
        h.div([attr.class("nav-links")], [
          nav_link("/", "~/hjem", model.route == Home),
          nav_link("/projects", "~/prosjekter", case model.route {
            Catalog | Project(_, _) -> True
            _ -> False
          }),
          nav_link("/om", "~/om", model.route == About),
        ]),
      ]),
    ]),
    h.main([], [
      view_page(model),
      case model.route {
        Project(id, _) -> discovery.onward(id) |> element.map(DiscoveryMessage)
        _ -> h.text("")
      },
    ]),
    h.footer([attr.class("shell-footer")], [
      h.span([], [h.text("≠ ulik.no — " <> model.version)]),
      deploy.view(model.deploy) |> element.map(DeployMessage),
    ]),
  ])
}

fn nav_link(
  destination: String,
  label: String,
  active: Bool,
) -> Element(message) {
  h.a(
    [
      attr.href(destination),
      attr.class(case active {
        True -> "menu-link active"
        False -> "menu-link"
      }),
      attr.attribute("aria-current", case active {
        True -> "page"
        False -> "false"
      }),
    ],
    [h.text(label)],
  )
}

fn view_page(model: Model) -> Element(Message) {
  let wrap = fn(message) { PageMessage(model.revision, message) }
  case model.page {
    HomePage ->
      discovery.view_home(model.discovery) |> element.map(DiscoveryMessage)
    CatalogPage ->
      discovery.view_catalog(model.discovery) |> element.map(DiscoveryMessage)
    AboutPage ->
      h.div([attr.class("about-page")], [
        h.section([attr.class("terminal-panel about")], [
          h.p([attr.class("prompt")], [h.text("$ cat ./om.txt")]),
          h.h1([], [h.text("Om")]),
          h.p([], [
            h.text(
              "Her samler jeg prototyper, verktøy og idéer som lukter litt kode, kanskje litt språkmodell og litt ren nysgjerrighet.",
            ),
          ]),
          h.p([], [
            h.text(
              "Målet med ulik.no er å være et eksperimentrom for små prosjekter, AI-testing og ting som ikke passer inn andre steder.",
            ),
          ]),
        ]),
      ])
    PlaceholderPage -> placeholder()
    NotFoundPage ->
      h.section([attr.class("terminal-panel")], [
        h.h1([], [h.text("Fant ikke siden")]),
        h.a([attr.href("/projects")], [h.text("Se alle prosjekter")]),
      ])
    FlowPage(state) ->
      flow.view(state) |> element.map(FlowMessage) |> element.map(wrap)
    RobotPage(state) ->
      robot.view(state) |> element.map(RobotMessage) |> element.map(wrap)
    FallingPage(state) ->
      falling.view(state) |> element.map(FallingMessage) |> element.map(wrap)
    NatoPage(state) ->
      nato.view(state) |> element.map(NatoMessage) |> element.map(wrap)
    MorsePage(state) ->
      morse.view(state) |> element.map(MorseMessage) |> element.map(wrap)
    DiffPage(state) ->
      diff.view(state) |> element.map(DiffMessage) |> element.map(wrap)
    ScreenPage(state) ->
      screen.view(state) |> element.map(ScreenMessage) |> element.map(wrap)
    IllusionsPage(state) ->
      illusions.view(state)
      |> element.map(IllusionsMessage)
      |> element.map(wrap)
  }
}

fn placeholder() -> Element(message) {
  h.div([attr.class("placeholder-page")], [
    h.section([attr.class("terminal-panel project-page")], [
      h.p([attr.class("prompt")], [
        h.text("$ cat ./prosjekter/prompt-lab/status.log"),
      ]),
      h.div([attr.class("project-head")], [
        h.h1([], [h.text("prompt≠lab")]),
        h.span([attr.class("status wip")], [h.text("under arbeid")]),
      ]),
      h.p([attr.class("description")], [
        h.text("Eksperimenter med AI-prompts og se hva som skjer."),
      ]),
      h.div(
        [attr.class("tags")],
        list.map(["ai", "llm", "prompting"], fn(tag) {
          h.span([], [h.text("[" <> tag <> "]")])
        }),
      ),
    ]),
    h.section([attr.class("terminal-panel construction")], [
      h.p([attr.class("prompt")], [h.text("$ tail -f deploy.log")]),
      h.div([attr.class("notice")], [
        h.span([attr.class("signal"), attr.attribute("aria-hidden", "true")], [
          h.text("≠"),
        ]),
        h.div([], [
          h.h2([], [h.text("Under konstruksjon")]),
          h.p([], [
            h.text(
              "Denne prosjektsiden er på vei opp. Inntil videre er prosjektet trygt parkert i terminalkøen.",
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

@external(javascript, "./navigation_ffi.mjs", "listen")
fn listen(on_navigate: fn(String) -> Nil) -> Nil

@external(javascript, "./navigation_ffi.mjs", "afterRender")
fn after_render(title: String, on_ready: fn() -> Nil) -> Nil
