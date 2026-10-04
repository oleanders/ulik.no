import gleam/list
import gleam/option.{type Option, None, Some}

pub type Id {
  Illusion
  Robot
  Falling
  Flow
  Nato
  Prompt
  Diff
  Screen
  Morse
}

pub type Category {
  Play
  Art
  Tools
}

pub type Status {
  Active
  UnderConstruction
}

pub type Project {
  Project(
    id: Id,
    category: Category,
    hook: String,
    interaction: String,
    title: String,
    description: String,
    tags: List(String),
    status: Status,
  )
}

pub fn all() -> List(Project) {
  [
    Project(
      Illusion,
      Art,
      "Ser ulikt ut. Er helt likt.",
      "Se · dra · avslør",
      "lik≠lik",
      "Tre optiske illusjoner du kan undersøke ved å fjerne omgivelsene.",
      ["illusjon", "persepsjon", "interaksjon"],
      Active,
    ),
    Project(
      Robot,
      Play,
      "To hjul. Din kontroll.",
      "Tastatur · 3D",
      "robot≠tohjul",
      "En to-hjuls robot som kjører rundt i en liten 3D-verden med tastaturstyring.",
      ["three.js", "3d", "robot"],
      Active,
    ),
    Project(
      Falling,
      Play,
      "Hva om hele siden ga etter?",
      "Trykk · kaos",
      "fall≠ned",
      "Se alle elementer falle ned og lande i en haug på bunnen.",
      ["animasjon", "css", "eksperiment"],
      Active,
    ),
    Project(
      Flow,
      Art,
      "Et lite dytt. Et helt nytt mønster.",
      "Peker / berøring",
      "flyt≠felt",
      "Et abstrakt, bevegelig bilde generert av et flow field på canvas.",
      ["canvas", "generativ", "animasjon"],
      Active,
    ),
    Project(
      Nato,
      Play,
      "Hør ordet. Finn bokstaven.",
      "Lyd · tastatur",
      "fonetisk≠spill",
      "Øv deg på det fonetiske alfabetet ved å høre ord og skriv riktige bokstaver.",
      ["språk", "spill", "speech"],
      Active,
    ),
    Project(
      Prompt,
      Tools,
      "Et laboratorium under bygging.",
      "Kommer snart",
      "prompt≠lab",
      "Eksperimenter med AI-prompts og se hva som skjer.",
      ["ai", "llm", "prompting"],
      UnderConstruction,
    ),
    Project(
      Diff,
      Tools,
      "Finn det som ikke er likt.",
      "Lim inn · sammenlign",
      "tekst≠diff",
      "Sammenlign to tekster og finn forskjellene.",
      ["verktøy", "tekst"],
      Active,
    ),
    Project(
      Screen,
      Tools,
      "Se hva nettleseren kan dele.",
      "Skjerm · lokal visning",
      "skjerm≠deling",
      "Test skjermdeling direkte i nettleseren med getDisplayMedia.",
      ["webrtc", "media", "eksperiment"],
      Active,
    ),
    Project(
      Morse,
      Play,
      "Prikk. Strek. Knekk koden.",
      "Lyd · berøring / tastatur",
      "morse≠kode",
      "Øv deg på å sende og motta morsekode med lyd, lys og tommelen.",
      ["spill", "morse", "lyd"],
      Active,
    ),
  ]
}

pub fn slug(id: Id) -> String {
  case id {
    Illusion -> "lik-lik"
    Robot -> "robot-tohjul"
    Falling -> "fall-haug"
    Flow -> "flyt-felt"
    Nato -> "fonetisk-alfabet"
    Prompt -> "prompt-lab"
    Diff -> "diff-tool"
    Screen -> "skjermdeling-lab"
    Morse -> "morsekode"
  }
}

pub fn from_slug(value: String) -> Option(Id) {
  case list.find(all(), fn(project) { slug(project.id) == value }) {
    Ok(project) -> Some(project.id)
    Error(_) -> None
  }
}

pub fn by_id(id: Id) -> Project {
  // Every constructor is represented in the catalog; the fallback is safe for
  // callers even if a future edit accidentally omits a catalog entry.
  case list.find(all(), fn(project) { project.id == id }) {
    Ok(project) -> project
    Error(_) ->
      Project(Prompt, Tools, "", "", "prompt≠lab", "", [], UnderConstruction)
  }
}

pub fn href(id: Id) -> String {
  "/projects/" <> slug(id)
}

pub fn category_label(category: Category) -> String {
  case category {
    Play -> "Lek og lær"
    Art -> "Generativ kunst"
    Tools -> "Små verktøy"
  }
}

pub fn surprise_candidates(excluded: Option(Id)) -> List(Project) {
  list.filter(all(), fn(project) {
    project.status == Active && Some(project.id) != excluded
  })
}

pub fn onward(id: Id) -> #(Option(Project), Option(Project)) {
  let current = by_id(id)
  let candidates = surprise_candidates(Some(id))
  #(
    candidates
      |> list.find(fn(project) { project.category == current.category })
      |> option.from_result,
    candidates
      |> list.find(fn(project) { project.category != current.category })
      |> option.from_result,
  )
}
