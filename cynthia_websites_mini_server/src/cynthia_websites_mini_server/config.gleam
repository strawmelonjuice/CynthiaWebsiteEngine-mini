import bungibindies/bun
import bungibindies/bun/sqlite
import cynthia_websites_mini_server/database
import cynthia_websites_mini_server/utils/files
import cynthia_websites_mini_server/utils/prompts
import cynthia_websites_mini_shared/configtype
import gleam/dict
import gleam/dynamic/decode
import gleam/fetch
import gleam/http/request
import gleam/javascript/promise
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleamy_lights/premixed
import plinth/javascript/console
import plinth/node/fs
import plinth/node/process
import simplifile
import tom

/// # Config.load()
/// Loads the configuration from the `cynthia-mini.toml` file and the content from the `content` directory.
/// Then saves the configuration to the database.
/// If an override environment variable or call param is provided, it will use that database file instead, and load from
/// there. It will not need any files to exist in the filesystem (except for the SQLite file) in that case.
pub fn load() -> #(sqlite.Database, configtype.SharedCynthiaConfig) {
  let global_conf_filepath =
    files.path_join([process.cwd(), "/cynthia-mini.toml"])
  let global_conf_filepath_exists = files.file_exist(global_conf_filepath)
  case global_conf_filepath_exists {
    True -> Nil
    False -> {
      dialog_initcfg()
      Nil
    }
  }
  let global_config = case
    i_load(
      global_conf_filepath,
      configtype.default_shared_cynthia_config_global_only,
    )
  {
    Ok(config) -> config
    Error(why) -> {
      premixed.text_error_red(
        "Error: Could not load cynthia-mini.toml: " <> why,
      )
      |> console.error
      process.exit(1)
      panic as "We should not reach here"
    }
  }
  let content = case content_getter() {
    Ok(lis) -> lis
    Error(msg) -> {
      console.error("Error: There was an error getting content:\n" <> msg)
      process.exit(1)
      panic as "We should not reach here"
    }
  }

  let conf =
    configtype.shared_merge_shared_cynthia_config(global_config, content)
  let db_path_env = case bun.env("CYNTHIA_MINI_DB") {
    Error(_) -> None

    Ok(path) -> Some(path)
  }
  let db = database.create_database(db_path_env)
  store_db(db, conf)
  #(db, conf)
}

pub type ContentKindOnly {
  ContentKind(kind: String)
}

pub fn content_kind_only_decoder() -> decode.Decoder(ContentKindOnly) {
  use kind <- decode.field("kind", decode.string)
  decode.success(ContentKind(kind:))
}

/// The old definition of parse_configtoml, used FFI. Now its just a redirect.
// @external(javascript, "./config_ffi.ts", "parse_configtoml")

fn i_load(
  _: String,
  _,
) -> Result(configtype.SharedCynthiaConfigGlobalOnly, String) {
  parse_configtoml()
}

fn parse_configtoml() {
  use str <- result.try(
    fs.read_file_sync(files.path_normalize(
      process.cwd() <> "/cynthia-mini.toml",
    ))
    |> result.map_error(fn(e) {
      premixed.text_error_red("Error: Could not read cynthia-mini.toml: " <> e)
      process.exit(1)
    })
    |> result.map_error(string.inspect),
  )
  use res <- result.try(tom.parse(str) |> result.map_error(string.inspect))

  use config <- result.try(
    cynthia_config_global_only_exploiter(res)
    |> result.map_error(string.inspect),
  )
  Ok(config)
}

type ConfigTomlDecodeError {
  TomlGetStringError(tom.GetError)
  TomlGetIntError(tom.GetError)
  FieldError(String)
}

fn cynthia_config_global_only_exploiter(o: dict.Dict(String, tom.Toml)) {
  use global_theme <- result.try({
    use field <- result.try(
      tom.get(o, ["global", "theme"])
      |> result.replace_error(FieldError("config->global.theme does not exist")),
    )
    tom.as_string(field)
    |> result.map_error(TomlGetStringError)
  })
  use global_theme_dark <- result.try({
    use field <- result.try(
      tom.get(o, ["global", "theme_dark"])
      |> result.replace_error(FieldError(
        "config->global.theme_dark does not exist",
      )),
    )
    tom.as_string(field)
    |> result.map_error(TomlGetStringError)
  })
  use global_colour <- result.try({
    use field <- result.try(
      tom.get(o, ["global", "colour"])
      |> result.replace_error(FieldError("config->global.colour does not exist")),
    )
    tom.as_string(field)
    |> result.map_error(TomlGetStringError)
  })
  use global_site_name <- result.try({
    use field <- result.try(
      tom.get(o, ["global", "site_name"])
      |> result.replace_error(FieldError(
        "config->global.site_name does not exist",
      )),
    )
    tom.as_string(field)
    |> result.map_error(TomlGetStringError)
  })
  use global_site_description <- result.try({
    use field <- result.try(
      tom.get(o, ["global", "site_description"])
      |> result.replace_error(FieldError(
        "config->global.site_description does not exist",
      )),
    )
    tom.as_string(field)
    |> result.map_error(TomlGetStringError)
  })
  let server_port =
    option.from_result({
      use field <- result.try(
        tom.get(o, ["server", "port"])
        |> result.replace_error(FieldError("config->server.port does not exist")),
      )
      tom.as_int(field)
      |> result.map_error(TomlGetIntError)
    })
  let server_host =
    option.from_result({
      use field <- result.try(
        tom.get(o, ["server", "host"])
        |> result.replace_error(FieldError("config->server.host does not exist")),
      )
      tom.as_string(field)
      |> result.map_error(TomlGetStringError)
    })
  let posts_comments = case
    tom.get(o, ["posts", "comments"]) |> result.map(tom.as_bool)
  {
    Ok(Ok(field)) -> {
      field
    }
    _ -> True
  }
  Ok(configtype.SharedCynthiaConfigGlobalOnly(
    global_theme:,
    global_theme_dark:,
    global_colour:,
    global_site_name:,
    global_site_description:,
    server_port:,
    server_host:,
    posts_comments:,
  ))
}

fn content_getter() {
  {
    simplifile.get_files(files.path_join([process.cwd() <> "/content"]))
    |> result.unwrap([])
    |> list.filter(fn(file) { file |> string.ends_with(".meta.json") })
    |> list.map(fn(file) {
      file
      |> string.replace(".meta.json", "")
      |> files.path_normalize()
    })
    |> list.try_map(fn(file) -> Result(configtype.Contents, String) {
      use content <- result.try({
        fs.read_file_sync(files.path_normalize(file <> ".meta.json"))
        |> result.replace_error(
          "Error: Could not read file " <> file <> ".meta.json",
        )
      })
      use kind <- result.try({
        json.parse(content, content_kind_only_decoder())
        |> result.replace_error(
          "Error: Could not decode kind in " <> file <> ".meta.json",
        )
      })
      case kind.kind {
        "page" -> {
          use page <- result.try({
            json.parse(content, configtype.page_decoder(file))
            |> result.replace_error(
              "Error: Could not decode the page metadata in "
              <> files.path_normalize(premixed.text_magenta(
                file <> ".meta.json",
              )),
            )
          })
          Ok(configtype.ContentsPage(page))
        }
        "post" -> {
          use post <- result.try({
            json.parse(content, configtype.post_decoder(file))
            |> result.replace_error(
              "Error: Could not decode the post metadata in "
              <> files.path_normalize(premixed.text_magenta(
                file <> ".meta.json",
              )),
            )
          })
          Ok(configtype.ContentsPost(post))
        }
        _ ->
          Error(
            "Error: Could not decode "
            <> files.path_normalize(premixed.text_magenta(file <> ".meta.json")),
          )
      }
    })
  }
}

pub fn store_db(
  db: sqlite.Database,
  conf: configtype.SharedCynthiaConfig,
) -> Nil {
  // Is this just going to be an alias function?
  database.save_complete_config(db, conf)
}

pub fn update_content_in_db(
  db: sqlite.Database,
  config: configtype.SharedCynthiaConfigGlobalOnly,
) -> Nil {
  case content_getter() {
    Ok(content) -> {
      let conf = configtype.shared_merge_shared_cynthia_config(config, content)
      store_db(db, conf)
    }
    Error(msg) -> {
      console.error("Error: There was an error getting content:\n" <> msg)
      process.exit(1)
      panic as "We should not reach here"
    }
  }
}

fn dialog_initcfg() {
  console.log("No Cynthia Mini configuration found...")
  case
    prompts.for_confirmation(
      "CynthiaMini can create \n"
        <> premixed.text_orange(process.cwd() <> "/cynthia-mini.toml")
        <> "\n ...and some sample content.\n"
        <> premixed.text_magenta(
        "Do you want to initialise new config at this location?",
      ),
      True,
    )
  {
    False -> {
      console.error("No Cynthia Mini configuration found... Exiting.")
      process.exit(1)
      panic as "We should not reach here"
    }
    True -> Nil
  }
  let assert Ok(_) =
    simplifile.create_directory_all(process.cwd() <> "/content")
  let assert Ok(_) = simplifile.create_directory_all(process.cwd() <> "/assets")
  let _ =
    { process.cwd() <> "/cynthia-mini.toml" }
    |> fs.write_file_sync(
      "[global]
theme = \"autumn\"
theme_dark = \"night\"
colour = \"#FFFFFF\"
site_name = \"My Site\"
site_description = \"A big site on a mini Cynthia!\"
[server]
port = 8080
host = \"localhost\"
[posts]
comments = false
",
    )
    |> result.map_error(fn(e) {
      premixed.text_error_red("Error: Could not write cynthia-mini.toml: " <> e)
      process.exit(1)
    })
  {
    console.log("Downloading default site icon...")
    // Download https://raw.githubusercontent.com/strawmelonjuice/CynthiaWebsiteEngine-mini/refs/heads/main/asset/153916590.png to assets/site_icon.png
    // Ignore any errors, if it fails, it fails.
    let assert Ok(req) =
      request.to(
        "https://raw.githubusercontent.com/strawmelonjuice/CynthiaWebsiteEngine-mini/refs/heads/main/asset/153916590.png",
      )
    use resp <- promise.try_await(fetch.send(req))
    use resp <- promise.try_await(fetch.read_bytes_body(resp))
    case
      simplifile.write_bits(process.cwd() <> "/assets/site_icon.png", resp.body)
    {
      Ok(_) -> Nil
      Error(_) -> {
        console.error("Error: Could not write assets/site_icon.png")
        Nil
      }
    }
    promise.resolve(Ok(Nil))
  }
  {
    {
      []
      |> create_page(
        "index.md",
        configtype.Page(
          filename: "",
          title: "Example index",
          description: "This is an example index page",
          layout: "theme",
          permalink: "/",
          page: configtype.ContentsPagePageData(menus: [1]),
        ),
        "# Hello, World

Hello! This is an example page, you'll find me at `content/index.md`.

I'm written in Markdown, and I'm rendered to HTML by Cynthia Mini!

Here's a list of things you can do with me:

- Lists!
- [Links](https://github.com/strawmelonjuice/CynthiaWebSiteEngine-Mini) and even [relative links](/example-post)
- **Bold** and *italic* text

1. Numbered lists
2. Images: ![Gleam's Lucy mascot](https://gleam.run/images/lucy/lucy.svg)

## The world is big

### The world is a little smaller

#### The world is tiny

##### The world is tinier

###### The world is the tiniest

> Also quote blocks!
>
> -StrawmelonJuice

```bash
echo \"Code blocks!\"
// - StrawmelonJuice
```
",
      )
      |> create_post(
        to: "example-post.md",
        with: configtype.Post(
          filename: "",
          title: "An example post!",
          description: "This is an example post",
          layout: "theme",
          permalink: "/example-post",
          post: configtype.PostMetaData(
            category: "example",
            date_posted: "2021-01-01",
            date_updated: "2021-01-01",
            tags: ["example"],
          ),
        ),
        containing: "# Hello, World!\n\nHello! This is an example post, you'll find me at `content/example-post.md`.",
      )
      |> create_page(
        to: "posts",
        with: configtype.Page(
          filename: "posts",
          title: "Posts",
          description: "this page is not actually shown, due to the ! prefix in the permalink",
          layout: "default",
          permalink: "!/",
          page: configtype.ContentsPagePageData(menus: [1]),
        ),
        containing: "",
      )
    }
  }
  |> write_posts_and_pages_to_fs
}

fn create_post(
  after others: List(#(String, String)),
  to path: String,
  with meta: configtype.Post,
  containing inner: String,
) -> List(#(String, String)) {
  let path = files.path_join([process.cwd(), "/content/", path])
  let meta_json =
    json.object([
      #("title", json.string(meta.title)),
      #("description", json.string(meta.description)),
      #("kind", json.string("post")),
      #("layout", json.string(meta.layout)),
      #("permalink", json.string(meta.permalink)),
      #(
        "post",
        json.object([
          #("category", json.string(meta.post.category)),
          #("date-posted", json.string(meta.post.date_posted)),
          #("date-updated", json.string(meta.post.date_updated)),
          #("tags", json.array(meta.post.tags, json.string)),
        ]),
      ),
    ])
    |> json.to_string()
  let meta_path = path <> ".meta.json"
  [#(meta_path, meta_json), #(path, inner)]
  |> list.append(others)
}

fn create_page(
  after others: List(#(String, String)),
  to path: String,
  with meta: configtype.Page,
  containing inner: String,
) -> List(#(String, String)) {
  let path = files.path_join([process.cwd(), "/content/", path])
  let meta_json =
    json.object([
      #("title", json.string(meta.title)),
      #("description", json.string(meta.description)),
      #("kind", json.string("page")),
      #("layout", json.string(meta.layout)),
      #("permalink", json.string(meta.permalink)),
      #(
        "page",
        json.object([#("menus", json.array(meta.page.menus, json.int))]),
      ),
    ])
    |> json.to_string()
  let meta_path = path <> ".meta.json"
  [#(meta_path, meta_json), #(path, inner)]
  |> list.append(others)
}

// What? The function name is descriptive!
fn write_posts_and_pages_to_fs(items: List(#(String, String))) -> Nil {
  items
  |> list.each(fn(set) {
    let #(path, content) = set
    path
    |> fs.write_file_sync(content)
  })
}
