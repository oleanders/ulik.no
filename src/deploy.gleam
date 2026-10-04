import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html

pub type Status {
  Running
  Success
  Failure
  Cancelled
  Other(String)
}

pub type Run {
  Run(url: String, status: Status)
}

pub type Model {
  Loading
  Unavailable
  NoDeploy
  Latest(Run)
}

pub type Message {
  Fetched(Result(List(Run), Nil))
  Refresh
}

pub fn init() -> Model {
  Loading
}

pub fn mount() -> Effect(Message) {
  fetch()
}

fn fetch() -> Effect(Message) {
  effect.from(fn(dispatch) {
    fetch_runs(fn(value) { dispatch(Fetched(decode_runs(value))) }, fn() {
      dispatch(Fetched(Error(Nil)))
    })
  })
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    Refresh -> #(model, fetch())
    Fetched(result) -> {
      let model = case result {
        Error(_) -> Unavailable
        Ok([]) -> NoDeploy
        Ok([run, ..]) -> Latest(run)
      }
      #(
        model,
        effect.from(fn(dispatch) {
          schedule_refresh(poll_interval(model), fn() { dispatch(Refresh) })
        }),
      )
    }
  }
}

pub fn poll_interval(model: Model) -> Int {
  case model {
    Latest(Run(_, Running)) -> 15_000
    _ -> 60_000
  }
}

pub fn run_status(status: String, conclusion: Option(String)) -> Status {
  case
    list.contains(
      ["in_progress", "queued", "pending", "waiting", "requested"],
      status,
    )
  {
    True -> Running
    False ->
      case conclusion {
        Some("success") -> Success
        Some("failure") -> Failure
        Some("cancelled") -> Cancelled
        Some(other) -> Other(other)
        None -> Other(status)
      }
  }
}

pub fn decode_runs(value: Dynamic) -> Result(List(Run), Nil) {
  let run_decoder = {
    use name <- decode.field("name", decode.string)
    use url <- decode.field("html_url", decode.string)
    use status <- decode.field("status", decode.string)
    use conclusion <- decode.field("conclusion", decode.optional(decode.string))
    decode.success(#(name, Run(url, run_status(status, conclusion))))
  }
  let decoder = {
    use runs <- decode.field("workflow_runs", decode.list(run_decoder))
    decode.success(runs)
  }
  case decode.run(value, decoder) {
    Error(_) -> Error(Nil)
    Ok(runs) ->
      Ok(
        runs
        |> list.filter(fn(named_run) {
          list.contains(
            [
              "Deploy to beta on push to main",
              "Deploy to production when release is published",
            ],
            named_run.0,
          )
        })
        |> list.map(fn(named_run) { named_run.1 }),
      )
  }
}

pub fn view(model: Model) -> Element(Message) {
  let #(label, dot) = case model {
    Loading -> #("laster deploy-status…", "idle")
    Unavailable -> #("status utilgjengelig", "idle")
    NoDeploy -> #("ingen deploy registrert", "idle")
    Latest(run) ->
      case run.status {
        Running -> #("deploy pågår", "live")
        Success -> #("siste deploy ok", "ok")
        Failure -> #("siste deploy feilet", "fail")
        Cancelled -> #("siste deploy avbrutt", "idle")
        Other(state) -> #("siste deploy: " <> state, "idle")
      }
  }
  let content = [
    html.span(
      [attr.class("dot " <> dot), attr.attribute("aria-hidden", "true")],
      [],
    ),
    html.span([], [text(label)]),
  ]
  html.div([attr.class("deploy-status")], [
    case model {
      Latest(run) ->
        html.a(
          [
            attr.class("status"),
            attr.href(run.url),
            attr.target("_blank"),
            attr.rel("noreferrer"),
          ],
          content,
        )
      _ -> html.span([attr.class("status")], content)
    },
  ])
}

@external(javascript, "./deploy_ffi.mjs", "fetchRuns")
fn fetch_runs(on_success: fn(Dynamic) -> Nil, on_failure: fn() -> Nil) -> Nil

@external(javascript, "./deploy_ffi.mjs", "scheduleRefresh")
fn schedule_refresh(milliseconds: Int, on_refresh: fn() -> Nil) -> Nil

@external(javascript, "./deploy_ffi.mjs", "dispose")
pub fn dispose() -> Nil
