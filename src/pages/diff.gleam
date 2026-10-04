import gleam/int
import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event

pub type Mode {
  Lines
  Words
}

pub type Change {
  Change(value: String, count: Int, added: Bool, removed: Bool)
}

pub type Statistics {
  Statistics(added: Int, removed: Int)
}

pub type Model {
  Model(left: String, right: String, mode: Mode, changes: List(Change))
}

pub type Message {
  EditLeft(String)
  EditRight(String)
  SetMode(Mode)
  Swap
  Clear
}

// The existing jsdiff algorithm is synchronous. There is no untyped message
// protocol or asynchronous result that can overwrite a newer edit.
@external(javascript, "../tools_ffi.mjs", "compareText")
fn compare_text(
  left: String,
  right: String,
  by_words: Bool,
  change: fn(String, Int, Bool, Bool) -> Change,
) -> List(Change)

// Keep the original browser tool's UTF-16 character counts, including emoji.
@external(javascript, "../tools_ffi.mjs", "characterCount")
fn character_count(value: String) -> Int

pub fn init() -> Model {
  recompute(
    Model(
      left: "# handleliste\nmelk\nbrød\negg\nkaffe\nsjokolade",
      right: "# handleliste\nhavremelk\nbrød\negg\nkaffe\nte\nmørk sjokolade",
      mode: Lines,
      changes: [],
    ),
  )
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  let model = case message {
    EditLeft(input) -> Model(..model, left: input)
    EditRight(input) -> Model(..model, right: input)
    SetMode(mode) -> Model(..model, mode: mode)
    Swap -> Model(..model, left: model.right, right: model.left)
    Clear -> Model(..model, left: "", right: "")
  }
  #(recompute(model), effect.none())
}

fn recompute(model: Model) -> Model {
  Model(
    ..model,
    changes: compare_text(model.left, model.right, model.mode == Words, Change),
  )
}

pub fn statistics(mode: Mode, changes: List(Change)) -> Statistics {
  list.fold(changes, Statistics(0, 0), fn(totals, part) {
    let count = case mode {
      Lines -> part.count
      Words -> character_count(part.value)
    }
    case part.added, part.removed {
      True, _ -> Statistics(..totals, added: totals.added + count)
      False, True -> Statistics(..totals, removed: totals.removed + count)
      _, _ -> totals
    }
  })
}

pub fn view(model: Model) -> Element(Message) {
  html.div([attribute.class("diff-page")], [
    html.section([attribute.class("terminal-panel head")], [
      html.p([attribute.class("prompt")], [
        text("$ diff ./venstre.txt ./hoyre.txt"),
      ]),
      html.div([attribute.class("head-row")], [
        html.h1([], [text("tekst≠diff")]),
        html.span([attribute.class("status active")], [text("aktiv")]),
      ]),
      html.p([attribute.class("desc")], [
        text(
          "Lim inn tekst i de to boksene, så vises forskjellene under. Bytt mellom linje- og ordsammenlikning, bytt om sidene, eller tøm alt.",
        ),
      ]),
      html.div([attribute.class("controls")], [
        html.div(
          [
            attribute.class("mode"),
            attribute.role("group"),
            attribute.aria_label("Sammenlikningsmodus"),
          ],
          [
            mode_button(model.mode, Lines, "linjer"),
            mode_button(model.mode, Words, "ord"),
          ],
        ),
        html.button([attribute.type_("button"), event.on_click(Swap)], [
          text("↔ bytt"),
        ]),
        html.button([attribute.type_("button"), event.on_click(Clear)], [
          text("tøm"),
        ]),
      ]),
    ]),
    html.section([attribute.class("inputs")], [
      input_pane("~ /venstre", "lim inn første tekst…", model.left, EditLeft),
      input_pane("~ /høyre", "lim inn andre tekst…", model.right, EditRight),
    ]),
    output(model),
  ])
}

fn mode_button(
  selected: Mode,
  mode: Mode,
  caption: String,
) -> Element(Message) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class(case selected == mode {
        True -> "active"
        False -> ""
      }),
      attribute.attribute("aria-pressed", case selected == mode {
        True -> "true"
        False -> "false"
      }),
      event.on_click(SetMode(mode)),
    ],
    [text(caption)],
  )
}

fn input_pane(
  title: String,
  hint: String,
  input: String,
  edit: fn(String) -> Message,
) -> Element(Message) {
  html.label([attribute.class("pane")], [
    html.span([attribute.class("pane-head")], [text(title)]),
    html.textarea(
      [
        attribute.value(input),
        event.on_input(edit),
        attribute.spellcheck(False),
        attribute.placeholder(hint),
      ],
      input,
    ),
  ])
}

fn output(model: Model) -> Element(Message) {
  let totals = statistics(model.mode, model.changes)
  let result = case
    model.left == "" && model.right == "",
    model.left == model.right
  {
    True, _ -> html.p([attribute.class("empty")], [text("ingen inndata enda.")])
    _, True ->
      html.p([attribute.class("empty")], [text("tekstene er identiske.")])
    _, _ ->
      html.pre([attribute.class("diff")], list.map(model.changes, change_view))
  }
  html.section(
    [
      attribute.class("terminal-panel diff-output"),
      attribute.aria_label("Diff-resultat"),
    ],
    [
      html.div([attribute.class("diff-head")], [
        html.p([attribute.class("prompt")], [text("$ cat ./diff.patch")]),
        html.div([attribute.class("stats")], [
          html.span([attribute.class("added")], [
            text("+" <> int.to_string(totals.added)),
          ]),
          html.span([attribute.class("removed")], [
            text("-" <> int.to_string(totals.removed)),
          ]),
        ]),
      ]),
      result,
    ],
  )
}

fn change_view(change: Change) -> Element(Message) {
  let class = case change.added, change.removed {
    True, _ -> "added"
    False, True -> "removed"
    _, _ -> "context"
  }
  // User input is always a text node, never HTML.
  html.span([attribute.class("line " <> class)], [text(change.value)])
}
