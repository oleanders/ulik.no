module Projects exposing (Category(..), Id(..), Project, Status(..), all, byId, categoryLabel, fromSlug, href, onward, slug, surpriseCandidates)


type Id
    = Illusion
    | Robot
    | Falling
    | Flow
    | Nato
    | Prompt
    | Diff
    | Screen
    | Morse
    | NearMiss


type Category
    = Play
    | Art
    | Tools


type Status
    = Active
    | UnderConstruction


type alias Project =
    { id : Id
    , category : Category
    , hook : String
    , interaction : String
    , title : String
    , description : String
    , tags : List String
    , status : Status
    }


all : List Project
all =
    [ { id = NearMiss, category = Play, hook = "Bom så vidt du kan.", interaction = "Ett trykk · presisjon", title = "bom≠feil", description = "Skyt forbi. Jo nærmere du bommer, desto mer får du. Treffer du, er runden over.", tags = [ "spill", "presisjon", "ett trykk" ], status = Active }
    , { id = Illusion
      , category = Art
      , hook = "Ser ulikt ut. Er helt likt."
      , interaction = "Se · dra · avslør"
      , title = "lik≠lik"
      , description = "Tre optiske illusjoner du kan undersøke ved å fjerne omgivelsene."
      , tags = [ "illusjon", "persepsjon", "interaksjon" ]
      , status = Active
      }
    , { id = Robot
      , category = Play
      , hook = "To hjul. Din kontroll."
      , interaction = "Tastatur · 3D"
      , title = "robot≠tohjul"
      , description = "En to-hjuls robot som kjører rundt i en liten 3D-verden med tastaturstyring."
      , tags = [ "three.js", "3d", "robot" ]
      , status = Active
      }
    , { id = Falling
      , category = Play
      , hook = "Hva om hele siden ga etter?"
      , interaction = "Trykk · kaos"
      , title = "fall≠ned"
      , description = "Se alle elementer falle ned og lande i en haug på bunnen."
      , tags = [ "animasjon", "css", "eksperiment" ]
      , status = Active
      }
    , { id = Flow
      , category = Art
      , hook = "Et lite dytt. Et helt nytt mønster."
      , interaction = "Peker / berøring"
      , title = "flyt≠felt"
      , description = "Et abstrakt, bevegelig bilde generert av et flow field på canvas."
      , tags = [ "canvas", "generativ", "animasjon" ]
      , status = Active
      }
    , { id = Nato
      , category = Play
      , hook = "Hør ordet. Finn bokstaven."
      , interaction = "Lyd · tastatur"
      , title = "fonetisk≠spill"
      , description = "Øv deg på det fonetiske alfabetet ved å høre ord og skriv riktige bokstaver."
      , tags = [ "språk", "spill", "speech" ]
      , status = Active
      }
    , { id = Prompt
      , category = Tools
      , hook = "Et laboratorium under bygging."
      , interaction = "Kommer snart"
      , title = "prompt≠lab"
      , description = "Eksperimenter med AI-prompts og se hva som skjer."
      , tags = [ "ai", "llm", "prompting" ]
      , status = UnderConstruction
      }
    , { id = Diff
      , category = Tools
      , hook = "Finn det som ikke er likt."
      , interaction = "Lim inn · sammenlign"
      , title = "tekst≠diff"
      , description = "Sammenlign to tekster og finn forskjellene."
      , tags = [ "verktøy", "tekst" ]
      , status = Active
      }
    , { id = Screen
      , category = Tools
      , hook = "Se hva nettleseren kan dele."
      , interaction = "Skjerm · lokal visning"
      , title = "skjerm≠deling"
      , description = "Test skjermdeling direkte i nettleseren med getDisplayMedia."
      , tags = [ "webrtc", "media", "eksperiment" ]
      , status = Active
      }
    , { id = Morse
      , category = Play
      , hook = "Prikk. Strek. Knekk koden."
      , interaction = "Lyd · berøring / tastatur"
      , title = "morse≠kode"
      , description = "Øv deg på å sende og motta morsekode med lyd, lys og tommelen."
      , tags = [ "spill", "morse", "lyd" ]
      , status = Active
      }
    ]


slug : Id -> String
slug id =
    case id of
        NearMiss ->
            "bom-feil"

        Illusion ->
            "lik-lik"

        Robot ->
            "robot-tohjul"

        Falling ->
            "fall-haug"

        Flow ->
            "flyt-felt"

        Nato ->
            "fonetisk-alfabet"

        Prompt ->
            "prompt-lab"

        Diff ->
            "diff-tool"

        Screen ->
            "skjermdeling-lab"

        Morse ->
            "morsekode"


fromSlug : String -> Maybe Id
fromSlug value =
    all |> List.filter (\project -> slug project.id == value) |> List.head |> Maybe.map .id


byId : Id -> Project
byId id =
    all |> List.filter (\project -> project.id == id) |> List.head |> Maybe.withDefault { id = Prompt, category = Tools, hook = "", interaction = "", title = "prompt≠lab", description = "", tags = [], status = UnderConstruction }


href : Id -> String
href id =
    "/projects/" ++ slug id


categoryLabel : Category -> String
categoryLabel category =
    case category of
        Play ->
            "Lek og lær"

        Art ->
            "Generativ kunst"

        Tools ->
            "Små verktøy"


surpriseCandidates : Maybe Id -> List Project
surpriseCandidates excluded =
    List.filter (\project -> project.status == Active && Just project.id /= excluded) all


onward : Id -> ( Maybe Project, Maybe Project )
onward id =
    let
        current =
            byId id

        candidates =
            surpriseCandidates (Just id)

        related =
            List.filter (\project -> project.category == current.category) candidates |> List.head

        different =
            List.filter (\project -> project.category /= current.category) candidates |> List.head
    in
    ( related, different )
