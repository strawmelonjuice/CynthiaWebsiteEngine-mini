import bungibindies
import bungibindies/bun
import bungibindies/bun/http/serve.{ServeOptions}
import cynthia_websites_mini_server/config
import cynthia_websites_mini_server/static_routes
import cynthia_websites_mini_server/web
import gleam/option.{None, Some}
import gleamy_lights/console
import gleamy_lights/premixed
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
  let #(db, _conf) = config.load()
  console.log("Starting server...")
  let assert Ok(_) =
    bun.serve(ServeOptions(
      // TODO: Add hostname and port to the config file once flat config turns 3d
      development: Some(True),
      hostname: None,
      port: None,
      static_served: static_routes.static_routes(db),
      handler: web.handle_request(_, db),
      id: None,
      reuse_port: None,
    ))
  console.log("Server started!")
}
