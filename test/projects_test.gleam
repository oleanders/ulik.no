import deploy
import discovery
import gleam/dynamic
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element
import projects

pub fn all_nine_projects_have_unique_routable_identifiers_test() {
  projects.all()
  |> list.map(fn(project) { projects.slug(project.id) })
  |> list.unique
  |> list.length
  |> should.equal(9)
}

pub fn slugs_round_trip_through_routing_test() {
  projects.all()
  |> list.all(fn(project) {
    projects.from_slug(projects.slug(project.id)) == Some(project.id)
  })
  |> should.be_true
}

pub fn every_card_has_meaningful_metadata_test() {
  projects.all()
  |> list.all(fn(project) {
    !list.is_empty(project.tags)
    && string.length(project.hook) > 5
    && string.length(project.interaction) > 5
    && string.length(projects.category_label(project.category)) > 0
  })
  |> should.be_true
}

pub fn surprise_excludes_placeholders_and_current_project_test() {
  projects.all()
  |> list.all(fn(current) {
    projects.surprise_candidates(Some(current.id))
    |> list.all(fn(project) {
      project.status == projects.Active && project.id != current.id
    })
  })
  |> should.be_true
  projects.surprise_candidates(None)
  |> list.length
  |> should.equal(8)
}

pub fn onward_routes_are_active_related_and_distinct_test() {
  projects.all()
  |> list.all(fn(current) {
    let #(related, different) = projects.onward(current.id)
    case related, different {
      Some(related), Some(different) -> {
        related.id != current.id
        && different.id != current.id
        && related.id != different.id
        && related.status == projects.Active
        && different.status == projects.Active
        && related.category == current.category
        && different.category != current.category
      }
      _, _ -> False
    }
  })
  |> should.be_true
}

pub fn unknown_routes_are_not_invented_test() {
  projects.from_slug("unknown") |> should.equal(None)
  projects.from_slug("/morsekode") |> should.equal(None)
}

pub fn catalog_filter_updates_count_and_pressed_state_test() {
  let #(model, _) =
    discovery.update(
      discovery.init(),
      discovery.FilterBy(discovery.Category(projects.Art)),
    )
  model.filter |> should.equal(discovery.Category(projects.Art))
  let markup = element.to_string(discovery.view_catalog(model))
  string.contains(markup, "Viser 2 av 9 prosjekter") |> should.be_true
  string.contains(markup, "lik≠lik") |> should.be_true
  string.contains(markup, "flyt≠felt") |> should.be_true
  string.contains(markup, "robot≠tohjul") |> should.be_false
  string.contains(markup, "aria-pressed=\"true\"") |> should.be_true
}

pub fn preview_state_and_toggle_keep_accessible_controls_in_sync_test() {
  let #(model, _) =
    discovery.update(discovery.init(), discovery.PreviewChanged(True, False))
  model.reduced_motion |> should.be_true
  model.playback |> should.equal(discovery.Paused)
  let markup = element.to_string(discovery.view_home(model))
  string.contains(markup, "Et stille mønster.") |> should.be_true
  string.contains(markup, "Start bevegelse") |> should.be_true
  let #(model, _) = discovery.update(model, discovery.Toggle)
  model.playback |> should.equal(discovery.Playing)
  element.to_string(discovery.view_home(model))
  |> string.contains("Pause bevegelse")
  |> should.be_true
}

pub fn deploy_status_maps_all_lifecycle_states_test() {
  ["in_progress", "queued", "pending", "waiting", "requested"]
  |> list.all(fn(status) { deploy.run_status(status, None) == deploy.Running })
  |> should.be_true
  deploy.run_status("completed", Some("success"))
  |> should.equal(deploy.Success)
  deploy.run_status("completed", Some("failure"))
  |> should.equal(deploy.Failure)
  deploy.run_status("completed", Some("cancelled"))
  |> should.equal(deploy.Cancelled)
  deploy.run_status("completed", Some("skipped"))
  |> should.equal(deploy.Other("skipped"))
  deploy.run_status("unknown", None) |> should.equal(deploy.Other("unknown"))
}

pub fn deploy_polling_tracks_active_run_and_recovers_from_failure_test() {
  let run =
    deploy.Run(
      "https://github.com/oleanders/ulik.no/actions/runs/1",
      deploy.Running,
    )
  let #(active, _) = deploy.update(deploy.init(), deploy.Fetched(Ok([run])))
  active |> should.equal(deploy.Latest(run))
  deploy.poll_interval(active) |> should.equal(15_000)
  let #(unavailable, _) = deploy.update(active, deploy.Fetched(Error(Nil)))
  unavailable |> should.equal(deploy.Unavailable)
  deploy.poll_interval(unavailable) |> should.equal(60_000)
  let #(empty, _) = deploy.update(unavailable, deploy.Fetched(Ok([])))
  empty |> should.equal(deploy.NoDeploy)
  string.contains(
    element.to_string(deploy.view(empty)),
    "ingen deploy registrert",
  )
  |> should.be_true
}

fn workflow(
  name: String,
  url: String,
  status: String,
  conclusion: dynamic.Dynamic,
) -> dynamic.Dynamic {
  dynamic.properties([
    #(dynamic.string("name"), dynamic.string(name)),
    #(dynamic.string("html_url"), dynamic.string(url)),
    #(dynamic.string("status"), dynamic.string(status)),
    #(dynamic.string("conclusion"), conclusion),
  ])
}

pub fn deploy_decoder_filters_unrelated_workflows_and_preserves_recency_test() {
  let value =
    dynamic.properties([
      #(
        dynamic.string("workflow_runs"),
        dynamic.array([
          workflow(
            "CI",
            "https://github.com/ci",
            "completed",
            dynamic.string("failure"),
          ),
          workflow(
            "Deploy to beta on push to main",
            "https://github.com/beta",
            "in_progress",
            dynamic.nil(),
          ),
          workflow(
            "Deploy to production when release is published",
            "https://github.com/production",
            "completed",
            dynamic.string("success"),
          ),
        ]),
      ),
    ])
  deploy.decode_runs(value)
  |> should.equal(
    Ok([
      deploy.Run("https://github.com/beta", deploy.Running),
      deploy.Run("https://github.com/production", deploy.Success),
    ]),
  )
  deploy.decode_runs(dynamic.string("invalid")) |> should.equal(Error(Nil))
}
