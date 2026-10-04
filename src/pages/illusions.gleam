import gleam/float
import gleam/int
import gleam/list
import gleam/result
import lustre/attribute.{type Attribute, attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/element/svg
import lustre/event

pub type IllusionId {
  Color
  Circles
  Lines
}

pub type Illusion {
  Illusion(
    id: IllusionId,
    number: Int,
    title: String,
    question: String,
    description: String,
    measurement: String,
    explanation: String,
    source: String,
    source_label: String,
  )
}

pub type Model {
  Model(selected: IllusionId, revealed: Bool, strength: Int)
}

pub type Message {
  Select(IllusionId)
  ToggleReveal
  SetStrength(String)
  Reset
}

pub type Circle {
  Circle(x: Float, y: Float, radius: Float)
}

pub type LineEndpoints {
  LineEndpoints(x1: Int, x2: Int)
}

pub const target_color = "#82978b"

pub const target_radius = 28

pub const target_length = 280

pub const line_endpoints = LineEndpoints(x1: 220, x2: 500)

pub fn init() -> Model {
  Model(selected: Color, revealed: False, strength: 100)
}

pub fn mount() -> Effect(Message) {
  effect.none()
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  let next = case message {
    Select(selected) ->
      Model(selected: selected, revealed: False, strength: 100)
    ToggleReveal -> Model(..model, revealed: !model.revealed)
    SetStrength(input) -> {
      let strength = input |> int.parse |> result.unwrap(model.strength)
      Model(..model, strength: int.clamp(strength, min: 0, max: 100))
    }
    Reset -> Model(..model, revealed: False, strength: 100)
  }
  #(next, effect.none())
}

pub fn context_opacity(strength: Int, revealed: Bool) -> Float {
  case revealed {
    True -> 0.0
    False -> int.to_float(int.clamp(strength, min: 0, max: 100)) /. 100.0
  }
}

pub fn surrounding_circles(
  x: Float,
  radius: Float,
  distance: Float,
) -> List(Circle) {
  // The six points are spaced sixty degrees apart around a regular hexagon.
  let diagonal = 0.8660254037844386
  [
    #(1.0, 0.0),
    #(0.5, diagonal),
    #(-0.5, diagonal),
    #(-1.0, 0.0),
    #(-0.5, 0.0 -. diagonal),
    #(0.5, 0.0 -. diagonal),
  ]
  |> list.map(fn(offset) {
    Circle(
      x: x +. offset.0 *. distance,
      y: 135.0 +. offset.1 *. distance,
      radius: radius,
    )
  })
}

pub fn illusion(selected: IllusionId) -> Illusion {
  case selected {
    Color ->
      Illusion(
        id: Color,
        number: 1,
        title: "Samme farge",
        question: "Ser A og B ut som samme farge?",
        description: "To like fargefelt på ulik bakgrunn.",
        measurement: "Begge feltene: " <> target_color <> ".",
        explanation: "Begge feltene har nøyaktig samme fargekode. En lys bakgrunn kan få et felt til å se mørkere ut, og en mørk bakgrunn kan få det til å se lysere ut. Dette kalles simultankontrast.",
        source: "https://annex.exploratorium.edu/exhibits/mix_n_match/",
        source_label: "Exploratorium om farge og kontrast",
      )
    Circles ->
      Illusion(
        id: Circles,
        number: 2,
        title: "Samme sirkel",
        question: "Hvilken midtsirkel ser størst ut, A eller B?",
        description: "To like midtsirkler, omgitt av store og små sirkler.",
        measurement: "Begge midtsirklene: radius "
          <> int.to_string(target_radius)
          <> " i tegningen.",
        explanation: "Midtsirklene har samme radius. Størrelsen og plasseringen på sirklene rundt kan påvirke hvor store de ser ut. Dette er Ebbinghaus-illusjonen. Fjern omgivelsene og sammenlign igjen.",
        source: "https://michaelbach.de/ot/cog-Ebbinghaus/index.html",
        source_label: "Michael Bach om Ebbinghaus-illusjonen",
      )
    Lines ->
      Illusion(
        id: Lines,
        number: 3,
        title: "Samme linje",
        question: "Ser den vannrette linjen A eller B lengst ut?",
        description: "To like vannrette linjer med vinkler i ulike retninger ved endene.",
        measurement: "Begge strekene: "
          <> int.to_string(target_length)
          <> " enheter i tegningen.",
        explanation: "De vannrette strekene har samme lengde. Vinklene ved endene kan påvirke hvordan vi bedømmer lengden. Dette er Müller-Lyer-illusjonen. Målelinjene viser hvor strekene begynner og slutter.",
        source: "https://michaelbach.de/ot/sze-muelue/index.html",
        source_label: "Michael Bach om Müller-Lyer-illusjonen",
      )
  }
}

pub fn illusions() -> List(Illusion) {
  list.map([Color, Circles, Lines], illusion)
}

pub fn view(model: Model) -> Element(Message) {
  let current = illusion(model.selected)
  html.section(
    [
      attribute.class("illusions-page terminal-panel experiment"),
      attribute("aria-labelledby", "illusion-title"),
    ],
    [
      html.div([attribute.class("heading")], [
        html.div([], [
          html.p([attribute.class("prompt")], [text("$ ./lik --se-en-gang-til")]),
          html.h1([attribute.id("illusion-title")], [text("lik≠lik")]),
        ]),
        html.p([], [
          text("Det du ser "),
          html.span([attribute("aria-hidden", "true")], [text("≠")]),
          text(" det du måler."),
        ]),
      ]),
      html.div(
        [
          attribute.class("choices"),
          attribute("role", "group"),
          attribute("aria-label", "Velg illusjon"),
        ],
        list.map(illusions(), choice(model.selected, _)),
      ),
      html.div([attribute.class("question")], [
        html.h2([], [text(current.question)]),
        html.span([], [text(int.to_string(current.number) <> " / 3")]),
      ]),
      html.div([attribute.class("stage")], [scene(model, current)]),
      controls_view(model),
      html.div(
        [
          attribute.class("answer"),
          attribute("aria-live", "polite"),
          attribute("aria-atomic", "true"),
        ],
        case model.revealed {
          True -> [
            html.strong([], [text("A = B. Helt likt.")]),
            html.p([], [text(current.measurement)]),
            html.p([], [text(current.explanation)]),
          ]
          False -> [
            html.strong([], [text("Stol på øynene. Så sjekker du.")]),
            html.p([], [
              text(
                "Trykk «Avslør likheten», eller dra ned omgivelsene. Selve feltene, sirklene og strekene endres ikke.",
              ),
            ]),
          ]
        },
      ),
      html.div([attribute.class("bottom")], [
        html.a(
          [
            attribute.href(current.source),
            attribute("target", "_blank"),
            attribute("rel", "noreferrer"),
          ],
          [
            text("Les om fenomenet ↗"),
            html.span([attribute.class("sr-only")], [
              text(": " <> current.source_label <> " (åpnes i ny fane)"),
            ]),
          ],
        ),
        html.p([], [
          text(
            "Opplevelsen kan variere fra person til person. Ingen fasit på hva du ser.",
          ),
        ]),
      ]),
      element.element("noscript", [], [
        html.p([], [
          text(
            "Slå på JavaScript for å bruke kontrollene. I tegningen over er begge feltene "
            <> target_color
            <> ".",
          ),
        ]),
      ]),
    ],
  )
}

fn choice(selected: IllusionId, option: Illusion) -> Element(Message) {
  html.button(
    [
      attribute.type_("button"),
      pressed(selected == option.id),
      event.on_click(Select(option.id)),
    ],
    [
      html.span([], [text("0" <> int.to_string(option.number))]),
      text(" " <> option.title),
    ],
  )
}

fn pressed(is_pressed: Bool) -> Attribute(message) {
  attribute("aria-pressed", case is_pressed {
    True -> "true"
    False -> "false"
  })
}

fn controls_view(model: Model) -> Element(Message) {
  let visible_strength = case model.revealed {
    True -> 0
    False -> model.strength
  }
  html.div([attribute.class("controls")], [
    html.button(
      [
        attribute.class("reveal"),
        attribute.type_("button"),
        pressed(model.revealed),
        event.on_click(ToggleReveal),
      ],
      [
        text(case model.revealed {
          True -> "Vis illusjonen igjen"
          False -> "Avslør likheten"
        }),
      ],
    ),
    html.button([attribute.type_("button"), event.on_click(Reset)], [
      text("Nullstill"),
    ]),
    html.div([attribute.class("slider")], [
      html.label([attribute("for", "context-strength")], [
        text("Omgivelser "),
        html.output([attribute("for", "context-strength")], [
          text(int.to_string(visible_strength) <> "%"),
        ]),
      ]),
      html.input([
        attribute.id("context-strength"),
        attribute.type_("range"),
        attribute("min", "0"),
        attribute("max", "100"),
        attribute("step", "1"),
        attribute.value(int.to_string(visible_strength)),
        event.on_input(SetStrength),
        attribute.disabled(model.revealed),
        attribute("aria-describedby", "slider-help"),
      ]),
      html.span([attribute.id("slider-help")], [
        text("Dra mot 0 for å se uten omgivelsene."),
      ]),
    ]),
  ])
}

fn scene(model: Model, current: Illusion) -> Element(Message) {
  let drawing = case model.selected {
    Color -> color_scene(model)
    Circles -> circle_scene(model)
    Lines -> line_scene(model)
  }
  svg.svg(
    [
      attribute("viewBox", "0 0 720 310"),
      attribute("role", "img"),
      attribute("aria-labelledby", "scene-title scene-description"),
    ],
    [
      svg.title([attribute.id("scene-title")], [text(current.question)]),
      svg.desc([attribute.id("scene-description")], [
        text(
          current.description
          <> " Bruk kontrollene under bildet for å fjerne omgivelsene og vise målene.",
        ),
      ]),
      ..drawing
    ],
  )
}

fn context_attributes(model: Model) -> List(Attribute(message)) {
  [
    attribute(
      "opacity",
      float.to_string(context_opacity(model.strength, model.revealed)),
    ),
    attribute("data-testid", "context"),
  ]
}

fn color_scene(model: Model) -> List(Element(Message)) {
  [
    svg.g(context_attributes(model), [
      svg.rect([
        attribute("width", "360"),
        attribute("height", "260"),
        attribute("fill", "#101612"),
      ]),
      svg.rect([
        attribute("x", "360"),
        attribute("width", "360"),
        attribute("height", "260"),
        attribute("fill", "#e2e8e4"),
      ]),
    ]),
  ]
  |> list.append(
    list.map([180, 540], fn(x) {
      svg.rect([
        attribute("data-testid", "color-target"),
        attribute("x", int.to_string(x - 48)),
        attribute("y", "82"),
        attribute("width", "96"),
        attribute("height", "96"),
        attribute("fill", target_color),
      ])
    }),
  )
  |> list.append([
    scene_label("180", "292", "A"),
    scene_label("540", "292", "B"),
  ])
}

fn circle_scene(model: Model) -> List(Element(Message)) {
  let circles =
    surrounding_circles(180.0, 43.0, 89.0)
    |> list.append(surrounding_circles(540.0, 13.0, 48.0))
  [
    svg.g(
      [attribute("fill", "#427167"), ..context_attributes(model)],
      list.map(circles, fn(circle) {
        svg.circle([
          attribute("cx", float.to_string(circle.x)),
          attribute("cy", float.to_string(circle.y)),
          attribute("r", float.to_string(circle.radius)),
        ])
      }),
    ),
  ]
  |> list.append(
    list.map(["180", "540"], fn(x) {
      svg.circle([
        attribute("data-testid", "circle-target"),
        attribute("cx", x),
        attribute("cy", "135"),
        attribute("r", int.to_string(target_radius)),
        attribute("fill", "#ffc879"),
      ])
    }),
  )
  |> list.append(case model.revealed {
    True -> [
      measure(
        "M152 175 H208 M152 167 V183 M208 167 V183 M512 175 H568 M512 167 V183 M568 167 V183",
      ),
    ]
    False -> []
  })
  |> list.append([
    scene_label("180", "292", "A"),
    scene_label("540", "292", "B"),
  ])
}

fn line_scene(model: Model) -> List(Element(Message)) {
  [
    svg.g(
      context_attributes(model)
        |> list.append([
          attribute("stroke", "#86c6b4"),
          attribute("stroke-width", "5"),
          attribute("fill", "none"),
          attribute("stroke-linecap", "butt"),
        ]),
      [
        svg.path([
          attribute("d", "M264 45 L220 90 L264 135 M456 45 L500 90 L456 135"),
        ]),
        svg.path([
          attribute(
            "d",
            "M176 175 L220 220 L176 265 M544 175 L500 220 L544 265",
          ),
        ]),
      ],
    ),
  ]
  |> list.append(
    list.map(["90", "220"], fn(y) {
      svg.line([
        attribute("data-testid", "line-target"),
        attribute("x1", int.to_string(line_endpoints.x1)),
        attribute("x2", int.to_string(line_endpoints.x2)),
        attribute("y1", y),
        attribute("y2", y),
        attribute("stroke", "#ffc879"),
        attribute("stroke-width", "5"),
      ])
    }),
  )
  |> list.append([scene_label("105", "98", "A"), scene_label("105", "228", "B")])
  |> list.append(case model.revealed {
    True -> [measure("M220 50 V260 M500 50 V260 M220 155 H500")]
    False -> []
  })
}

fn scene_label(x: String, y: String, caption: String) -> Element(message) {
  svg.text([attribute("x", x), attribute("y", y)], caption)
}

fn measure(path: String) -> Element(message) {
  svg.path([attribute.class("measure"), attribute("d", path)])
}
