import gleam/float
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element
import pages/falling
import pages/flow
import pages/illusions
import pages/robot

fn flow_step(model: flow.Model, message: flow.Message) -> flow.Model {
  flow.update(model, message).0
}

fn robot_step(model: robot.Model, message: robot.Message) -> robot.Model {
  robot.update(model, message).0
}

fn illusion_step(
  model: illusions.Model,
  message: illusions.Message,
) -> illusions.Model {
  illusions.update(model, message).0
}

pub fn flow_preset_and_unsigned_seed_test() {
  flow.parse_config("v=1&preset=glod&seed=4294967295")
  |> should.equal(flow.Config(flow.Glod, 4_294_967_295, 1.5, 600, -0.5, 5))
}

pub fn flow_bounds_and_steps_test() {
  let bounded =
    flow.parse_config("speed=999&density=-100&attraction=-90&hue=1000")
  let snapped =
    flow.parse_config("speed=0.321&density=849&attraction=0.32&hue=12.2")
  #(bounded.speed, bounded.density, bounded.attraction, bounded.hue)
  |> should.equal(#(2.0, 300, -2.0, 359))
  #(snapped.speed, snapped.density, snapped.attraction, snapped.hue)
  |> should.equal(#(0.3, 800, 0.3, 12))
}

pub fn flow_rejects_malformed_numbers_test() {
  list.each(
    [
      "NaN",
      "Infinity",
      "-Infinity",
      "1e9",
      "%3Cscript%3E",
      "+",
      "",
      "1.12345",
      "1=2",
    ],
    fn(raw) {
      flow.parse_config(
        "speed="
        <> raw
        <> "&density="
        <> raw
        <> "&attraction="
        <> raw
        <> "&hue="
        <> raw,
      )
      |> should.equal(flow.parse_config(""))
    },
  )
}

pub fn flow_rejects_invalid_seeds_test() {
  list.each(["0", "-1", "4294967296", "1.5", "Infinity", "1e2", ""], fn(raw) {
    flow.parse_config("seed=" <> raw).seed |> should.equal(20_261_002)
  })
}

pub fn flow_rejects_unsupported_versions_and_large_queries_test() {
  list.each(
    [
      "v=2&preset=glod&seed=10",
      "v&preset=glod",
      "v=%zz&preset=glod",
      "seed=1&extra=" <> string.repeat("x", 1000),
    ],
    fn(query) {
      flow.parse_config(query) |> should.equal(flow.parse_config(""))
    },
  )
}

pub fn flow_malformed_parameter_does_not_discard_valid_parameters_test() {
  flow.parse_config("preset=glod&seed=%zz").preset |> should.equal(flow.Glod)
}

pub fn flow_all_presets_round_trip_test() {
  list.each([flow.Nordlys, flow.Virvel, flow.Glod], fn(preset) {
    let model =
      flow.init()
      |> flow_step(flow.LoadedUrl(
        "https://ulik.no/projects/flyt-felt?seed=4294967295&private=discard#discard",
      ))
      |> flow_step(flow.SelectPreset(preset))
      |> flow_step(flow.ChangeControl(flow.Speed, "0.3"))
      |> flow_step(flow.ChangeControl(flow.Attraction, "-1.8"))
      |> flow_step(flow.Share)
    let reopened = flow.init() |> flow_step(flow.LoadedUrl(model.share_url))
    reopened.config |> should.equal(model.config)
    string.contains(model.share_url, "discard") |> should.be_false
  })
}

pub fn flow_reduced_motion_can_be_overridden_test() {
  let paused = flow.init() |> flow_step(flow.Started(True))
  paused.playback |> should.equal(flow.Paused)
  paused.reduced_motion |> should.be_true
  flow_step(paused, flow.TogglePlayback).playback |> should.equal(flow.Playing)
}

pub fn flow_motion_change_pauses_but_does_not_autoplay_test() {
  let paused =
    flow.init()
    |> flow_step(flow.Started(False))
    |> flow_step(flow.MotionChanged(True))
  paused.playback |> should.equal(flow.Paused)
  flow_step(paused, flow.MotionChanged(False)).playback
  |> should.equal(flow.Paused)
}

pub fn flow_keyboard_pointer_bounds_and_release_test() {
  let moved =
    list.fold(list.repeat(0, 30), flow.init(), fn(model, _) {
      flow_step(model, flow.Key("ArrowRight"))
    })
  moved.pointer.x |> should.equal(1.0)
  moved.keyboard_active |> should.be_true
  flow_step(moved, flow.Restart).keyboard_active |> should.be_false
  flow_step(moved, flow.Key("Escape")).keyboard_active |> should.be_false
  flow_step(moved, flow.PointerUsed).keyboard_active |> should.be_false
}

pub fn flow_config_changes_clear_share_test() {
  flow.init()
  |> flow_step(flow.Share)
  |> flow_step(flow.ChangeControl(flow.Density, "1500"))
  |> fn(model) { model.share_url }
  |> should.equal("")
}

pub fn flow_export_lifecycle_test() {
  let initial = flow.init()
  flow_step(initial, flow.SavePng).exporting |> should.be_false
  let exporting =
    initial |> flow_step(flow.Started(False)) |> flow_step(flow.SavePng)
  exporting.exporting |> should.be_true
  flow_step(exporting, flow.Exported("done")).exporting |> should.be_false
}

pub fn flow_fixed_decimal_labels_test() {
  [flow.fixed(2, 0.3), flow.fixed(1, -1.8), flow.fixed(2, 2.0)]
  |> should.equal(["0.30", "-1.8", "2.00"])
}

pub fn flow_view_semantics_test() {
  let html = flow.init() |> flow.view |> element.to_string
  list.each(
    [
      "flow-canvas",
      "flow-wrapper",
      "flow-help",
      "flow-speed",
      "aria-label=\"Ditt flytfelt\"",
    ],
    fn(required) { string.contains(html, required) |> should.be_true },
  )
}

pub fn robot_repeated_keydowns_and_blur_test() {
  let pressed =
    robot.init()
    |> robot_step(robot.KeyDown("w"))
    |> robot_step(robot.KeyDown("w"))
  pressed.keys |> should.equal(["w"])
  robot_step(pressed, robot.ClearKeys).keys |> should.equal([])
}

pub fn robot_reduced_motion_test() {
  let paused = robot.init() |> robot_step(robot.Started(True))
  paused.running |> should.be_false
  let playing = paused |> robot_step(robot.ToggleRunning)
  playing.running |> should.be_true
  robot_step(playing, robot.MotionChanged(True)).running |> should.be_false
}

pub fn robot_touch_and_pause_release_test() {
  let pressed = robot.init() |> robot_step(robot.TouchDown("a"))
  pressed.touch_key |> should.equal(Some("a"))
  robot_step(pressed, robot.TouchUp).touch_key |> should.equal(None)
  robot_step(pressed, robot.ToggleRunning).touch_key |> should.equal(None)
}

pub fn robot_failure_stops_running_test() {
  let failed =
    robot.init()
    |> robot_step(robot.Started(False))
    |> robot_step(robot.FailedToStart("WebGL unavailable"))
  failed.status |> should.equal(robot.Failed("WebGL unavailable"))
  failed.running |> should.be_false
}

pub fn falling_restoration_and_settling_test() {
  let counted = falling.update(falling.init(), falling.Counted(8)).0
  let settled = falling.update(counted, falling.Finished).0
  #(settled.phase, settled.clone_count) |> should.equal(#(falling.Settled, 8))
  falling.update(settled, falling.Reset).0
  |> should.equal(falling.Model(falling.Restored, 0))
}

pub fn illusion_strength_reveal_and_reset_test() {
  let softened = illusions.init() |> illusion_step(illusions.SetStrength("35"))
  illusions.context_opacity(softened.strength, softened.revealed)
  |> should.equal(0.35)
  let revealed = softened |> illusion_step(illusions.ToggleReveal)
  illusions.context_opacity(revealed.strength, revealed.revealed)
  |> should.equal(0.0)
  revealed |> illusion_step(illusions.Reset) |> should.equal(illusions.init())
}

pub fn illusion_strength_clamping_test() {
  illusion_step(illusions.init(), illusions.SetStrength("-2")).strength
  |> should.equal(0)
  illusion_step(illusions.init(), illusions.SetStrength("120")).strength
  |> should.equal(100)
  illusion_step(illusions.init(), illusions.SetStrength("bad")).strength
  |> should.equal(100)
}

pub fn illusion_selection_resets_reveal_test() {
  let model =
    illusions.init()
    |> illusion_step(illusions.ToggleReveal)
    |> illusion_step(illusions.Select(illusions.Circles))
  #(model.selected, model.revealed, model.strength)
  |> should.equal(#(illusions.Circles, False, 100))
}

pub fn illusion_geometry_is_equal_test() {
  illusions.target_color |> should.equal("#82978b")
  illusions.target_radius |> should.equal(28)
  illusions.line_endpoints.x2 - illusions.line_endpoints.x1
  |> should.equal(illusions.target_length)
  let circles = illusions.surrounding_circles(180.0, 43.0, 89.0)
  list.length(circles) |> should.equal(6)
  list.each(circles, fn(circle) {
    let squared =
      { circle.x -. 180.0 }
      *. { circle.x -. 180.0 }
      +. { circle.y -. 135.0 }
      *. { circle.y -. 135.0 }
    { float.absolute_value(squared -. 89.0 *. 89.0) <. 0.000_001 }
    |> should.be_true
    circle.radius |> should.equal(43.0)
  })
}

pub fn illusion_all_scenes_render_with_descriptions_test() {
  list.each([illusions.Color, illusions.Circles, illusions.Lines], fn(selected) {
    list.each([False, True], fn(revealed) {
      let html =
        illusions.Model(selected, revealed, 70)
        |> illusions.view
        |> element.to_string
      list.each(
        [
          "scene-title",
          "scene-description",
          "context-strength",
          "aria-live=\"polite\"",
        ],
        fn(required) { string.contains(html, required) |> should.be_true },
      )
    })
  })
}

pub fn visual_aria_pressed_uses_html_boolean_spelling_test() {
  let flow_html = flow.init() |> flow.view |> element.to_string
  string.contains(flow_html, "aria-pressed=\"true\"") |> should.be_true
  string.contains(flow_html, "aria-pressed=\"false\"") |> should.be_true
  string.contains(flow_html, "aria-pressed=\"True\"") |> should.be_false
  let robot_html =
    robot.init()
    |> robot_step(robot.TouchDown("w"))
    |> robot.view
    |> element.to_string
  string.contains(robot_html, "aria-pressed=\"true\"") |> should.be_true
  string.contains(robot_html, "aria-pressed=\"false\"") |> should.be_true
  string.contains(robot_html, "aria-pressed=\"True\"") |> should.be_false
}

pub fn illusion_opacity_preserves_compact_svg_number_spelling_test() {
  let initial = illusions.init() |> illusions.view |> element.to_string
  string.contains(initial, "opacity=\"1\"") |> should.be_true
  let revealed =
    illusions.init()
    |> illusion_step(illusions.ToggleReveal)
    |> illusions.view
    |> element.to_string
  string.contains(revealed, "opacity=\"0\"") |> should.be_true
  let softened =
    illusions.init()
    |> illusion_step(illusions.SetStrength("35"))
    |> illusions.view
    |> element.to_string
  string.contains(softened, "opacity=\"0.35\"") |> should.be_true
}
