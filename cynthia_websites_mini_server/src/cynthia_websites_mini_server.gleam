import bungibindies
import bungibindies/bun
import bungibindies/bun/http/serve.{ServeOptions}
import cynthia_websites_mini_server/config
import cynthia_websites_mini_server/database
import cynthia_websites_mini_server/static_routes
import cynthia_websites_mini_server/web
import cynthia_websites_mini_server/web/comments
import cynthia_websites_mini_shared/configtype
import gleam/option.{None, Some}
import gleamy_lights/console
import gleamy_lights/premixed
import plinth/javascript/global
import plinth/node/process

pub fn main() {
  case bungibindies.runs_in_bun() {
    Ok(_) -> Nil
    Error(_) -> {
      console.log(premixed.text_red(
        "Error: Cynthia Mini needs to run in Bun! Try installing and running it with Bun instead.",
      ))
      process.exit(1)
    }
  }
  console.log(
    premixed.text_green("Hello from cynthia_websites_mini_server! ")
    <> "Running in "
    <> premixed.text_bright_orange(process.cwd())
    <> "!",
  )
  let #(db, conf) = config.load()
  console.log("Starting server...")
  let assert Ok(_) =
    bun.serve(ServeOptions(
      development: Some(True),
      hostname: conf.server_host,
      port: conf.server_port,
      static_served: static_routes.static_routes(db),
      handler: web.handle_request(_, db),
      id: None,
      reuse_port: None,
    ))
  console.log("Server started!")
  global.set_interval(60_000, fn() {
    // This function is called every minute
    let co =
      configtype.SharedCynthiaConfigGlobalOnly(
        global_theme: conf.global_theme,
        global_theme_dark: conf.global_theme_dark,
        global_colour: conf.global_colour,
        global_site_name: conf.global_site_name,
        global_site_description: conf.global_site_description,
        server_port: conf.server_port,
        server_host: conf.server_host,
        posts_comments: conf.posts_comments,
      )
    config.update_content_in_db(db, co)
    Nil
  })
  global.set_interval(40_000, fn() {
    comments.periodic_write_to_file(db)
    Nil
  })
}
