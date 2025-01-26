const tailwindconfig: import("tailwindcss").Config = {
  daisyui: {
    themes: ["autumn", "coffee"],
    darkMode: ["selector", '[data-theme="coffee"]'],
  },
  content: [
    "./cynthia_websites_mini_client/**/*.gleam",
    "./cynthia_websites_mini_server/src/cynthia_websites_mini_server/static_routes.gleam",
    "./cynthia_websites_mini_shared/src/cynthia_websites_mini_shared/ui.gleam",
  ],
  theme: {
    extend: {},
  },
  plugins: [require("daisyui")],
};

if (process.argv[2].toLowerCase() == "clean") {
  console.log("Cleaning up...");
  {
    const results: boolean[] = [];
    results.push(
      Bun.spawnSync({
        cmd: ["gleam", "clean"],
        cwd: "./cynthia_websites_mini_client/",
        // stderr: "inherit",
      }).success,
    );
    results.push(
      Bun.spawnSync({
        cmd: ["gleam", "clean"],
        cwd: "./cynthia_websites_mini_server/",
        // stderr: "inherit",
      }).success,
    );
    results.push(
      Bun.spawnSync({
        cmd: ["rm", "-rf", "./dist"],
      }).success,
    );
    results.push(
      Bun.spawnSync({
        cmd: ["rm", "-rf", "./node_modules/"],
      }).success,
    );
    results.push(
      Bun.spawnSync({
        cmd: [
          "rm",
          "-rf",
          "./cynthia_websites_mini_server/src/client_code_generated_ffi.ts",
        ],
      }).success,
    );
    results.push(
      Bun.spawnSync({
        cmd: ["rm", "-rf", "./cynthia_websites_mini_client/prelude.ts"],
      }).success,
    );
    results.push(
      Bun.spawnSync({
        cmd: ["rm", "-rf", "./cynthia_websites_mini_server/prelude.ts"],
      }).success,
    );

    if (results.every((x) => x)) {
      console.log("cleared.");
      process.exit(0);
    } else {
      console.error("cleaning failed, aborting");
      process.exit(1);
    }
  }
} else if (process.argv[2].toLowerCase() == "fmt") {
  let a = Bun.spawnSync({
    cmd: ["gleam", "format"],
    cwd: "./cynthia_websites_mini_server/",
    stdout: "inherit",
    stderr: "inherit",
  }).success;
  let b = Bun.spawnSync({
    cmd: ["gleam", "format"],
    cwd: "./cynthia_websites_mini_client/",
    stdout: "inherit",
    stderr: "inherit",
  }).success;
  if (a && b) {
    console.log("formatting successful.");
    process.exit(0);
  } else {
    console.error("formatting failed, aborting");
    process.exit(1);
  }
}
// Create links to the Gleam preludes, so that we can import them in FFI code.
// This is a workaround for the fact that Bun somehow doesn't seem to be respecting TSConfig rootdir paths.
{
  const fo = Bun.file(__dirname + "/cynthia_websites_mini_client/prelude.ts");
  fo.write(`export * from "./build/dev/javascript/prelude.mjs";`);
}
{
  const fo = Bun.file(__dirname + "/cynthia_websites_mini_server/prelude.ts");
  fo.write(`export * from "./build/dev/javascript/prelude.mjs";`);
}
console.log("Checking Bun dependencies...");
Bun.spawnSync({
  cmd: ["bun", "install"],
  stdout: "inherit",
  stderr: "inherit",
});
console.log("Building and bundling client code...");
{
  let o = Bun.spawnSync({
    cmd: ["gleam", "build"],
    cwd: "./cynthia_websites_mini_client/",
    stderr: "inherit",
  }).success;
  if (o) {
  } else {
    console.error("client build failed, aborting");
    process.exit(1);
  }

  if (
    !Bun.spawnSync({
      cmd: [
        "rm",
        "-rf",
        "./cynthia_websites_mini_client/build/dev/javascript/cynthia_websites_mini_client/gleam.ts",
      ],
    }).success
  ) {
    console.log(
      "Failed to remove ./cynthia_websites_mini_client/build/dev/javascript/cynthia_websites_mini_client/gleam.ts",
    );
  }
  await Bun.write(
    "./cynthia_websites_mini_client/build/dev/javascript/cynthia_websites_mini_client/cynthia_websites_mini_client.ts",
    `import { main } from "./cynthia_websites_mini_client.mjs";document.addEventListener("DOMContentLoaded", main());`,
  );
  // Bundle client code to a single file
  await Bun.build({
    entrypoints: [
      "./cynthia_websites_mini_client/build/dev/javascript/cynthia_websites_mini_client/cynthia_websites_mini_client.ts",
    ],
    outdir: "./cynthia_websites_mini_client/build/bundled/",
    minify: {
      whitespace: true,
      syntax: true,
      identifiers: false,
    },
    target: "browser",
  }).catch((e) => {
    console.error(e);
    process.exit(1);
  });
  let css = "/* Something has gone wrong building this CSS. */";

  const postcss = require("postcss");
  const tailwindcss = require("tailwindcss");

  const sourceCSS = "@tailwind base; @tailwind components; @tailwind utilities";
  const config = {
    presets: [tailwindconfig],
  };
  await postcss([tailwindcss(config)])
    .process(sourceCSS, { from: undefined })
    .then((genned_css: { css: string }) => {
      // `css` is a string of the compiled CSS.
      css = genned_css.css;
    })
    .catch((err: any) => {
      console.error(err);
    });
  const client_styles = JSON.stringify(css);

  const client_script = JSON.stringify(
    await Bun.file(
      "./cynthia_websites_mini_client/build/bundled/cynthia_websites_mini_client.js",
    ).text(),
  );
  console.log("Putting client script and styles into server code...");
  Bun.file(
    "./cynthia_websites_mini_server/src/client_code_generated_ffi.ts",
  ).write(
    `export function client_script() { return ${client_script}; }
export function client_styles() { return ${client_styles}; }`,
  );
}
console.log("Building and bundling server code...");
{
  // Compile the server code to JavaScript
  let o = Bun.spawnSync({
    cmd: ["gleam", "build"],
    cwd: "./cynthia_websites_mini_server/",
    stderr: "inherit",
  }).success;
  // Check if the build was successful
  if (o) {
  } else {
    console.error("server build failed, aborting");
    process.exit(1);
  }

  if (
    !Bun.spawnSync({
      cmd: [
        "rm",
        "-rf",
        "./cynthia_websites_mini_server/build/dev/javascript/cynthia_websites_mini_server/gleam.ts",
      ],
    }).success
  ) {
    console.log(
      "Failed to remove ./cynthia_websites_mini_server/build/dev/javascript/cynthia_websites_mini_server/gleam.ts",
    );
  }
  // Create entry point for the server
  await Bun.write(
    "./cynthia_websites_mini_server/build/dev/javascript/cynthia_websites_mini_server/cynthia_websites_mini_server.ts",
    `import { main } from "./cynthia_websites_mini_server.mjs";main();`,
  );
}
console.log("Prepping code successfully completed.");
  switch (process.argv[2].toLowerCase()) {
    case "gleam": {
      const argumens = process.argv.slice(3);
      console.log("Running" + (" `gleam " + argumens.join(" ")) + "` on both ends.");
      let a = Bun.spawnSync({
        cmd: ["gleam", ...argumens],
        cwd: "./cynthia_websites_mini_server/",
        stdout: "inherit",
        stderr: "inherit",
      }).success;
      let b = Bun.spawnSync({
        cmd: ["gleam", ...argumens],
        cwd: "./cynthia_websites_mini_client/",
        stdout: "inherit",
        stderr: "inherit",
      }).success;
      if (a && b) {
        console.log("gleam command successful.");
      } else {
        console.error("gleam command failed, aborting");
        process.exit(1);
      }
    }
    break;
    case "client-gleam": {
      const argumens = process.argv.slice(3);
      console.log("Running" + (" `gleam " + argumens.join(" ")) + "` on client.");
      let b = Bun.spawnSync({
        cmd: ["gleam", ...argumens],
        cwd: "./cynthia_websites_mini_client/",
        stdout: "inherit",
        stderr: "inherit",
      }).success;
      if (b) {
        console.log("gleam command successful.");
      } else {
        console.error("gleam command failed, aborting");
        process.exit(1);
      }
    }
      break;
    case "server-gleam": {
      const argumens = process.argv.slice(3);
      console.log("Running" + (" `gleam " + argumens.join(" ")) + "` on server.");
      let b = Bun.spawnSync({
        cmd: ["gleam", ...argumens],
        cwd: "./cynthia_websites_mini_server/",
        stdout: "inherit",
        stderr: "inherit",
      }).success;
      if (b) {
        console.log("gleam command successful.");
      } else {
        console.error("gleam command failed, aborting");
        process.exit(1);
      }
    }
      break;
    case "bundle": {
      const bytecode = process.argv.includes("--bytecode");
      const bcodestring = bytecode ? "bytecode" : "";
      console.log(`Compiling all to single ${bcodestring} package...`);
      {
        // Bundle code to dist
        let s = await Bun.build({
          minify: false,
          target: "bun",
          entrypoints: [
            "./cynthia_websites_mini_server/build/dev/javascript/cynthia_websites_mini_server/cynthia_websites_mini_server.ts",
          ],
          bytecode,
          outdir: "./dist",
        });
        if (s.success) console.log("Bundling completed.");
        else {
          console.error("Bundling failed, aborting\n\n" + s.logs);
          process.exit(1);
        }
      }
    }
    break;
    case "run": {
      console.log("Running server...");
      {
        // Run the server
        Bun.spawnSync({
          cmd: [
            "bun",
            "./cynthia_websites_mini_server/build/dev/javascript/cynthia_websites_mini_server/cynthia_websites_mini_server.ts",
          ],
          stdout: "inherit",
          stderr: "inherit",
          stdin: "inherit",
        });
      }
    }
    break;
    case "test":
    {
      console.log("Running tests...");
      {
        let results: boolean[] = [];
        // Run the tests
        if (!(process.argv[3].toLowerCase() === "client")) {
          console.log("Running tests for server:");
          results.push(Bun.spawnSync({
            cmd: ["gleam", "test"],
            cwd: "./cynthia_websites_mini_server/",
            stdout: "inherit",
            stderr: "inherit",
          }).success);
        }
        if (!(process.argv[3].toLowerCase() === "server")) {
          console.log("Running tests for client:");
          results.push(Bun.spawnSync({
            cmd: ["gleam", "test"],
            cwd: "./cynthia_websites_mini_client/",
            stdout: "inherit",
            stderr: "inherit",
          }).success);
        }
        if (results.every((x) => x)) {
          console.log("test(s) successful.");
        } else {
          console.error("test(s) failed!");
          process.exit(1);
        }
      }
    }
    break;
    case "check":
    {
      console.log("Checking code...");
      {
        // Check the code
        console.log("Checking server code:");
        let a = Bun.spawnSync({
          cmd: ["gleam", "check"],
          cwd: "./cynthia_websites_mini_server/",
          stdout: "inherit",
          stderr: "inherit",
        }).success;
        console.log("Checking client code:");
        let b = Bun.spawnSync({
          cmd: ["gleam", "check"],
          cwd: "./cynthia_websites_mini_client/",
          stdout: "inherit",
          stderr: "inherit",
        }).success;
        if (a && b) {
          console.log("checks successful.");
        } else {
          console.error("checks failed, aborting");
          process.exit(1);
        }
      }
    }
    break;
    default: {
      console.log("To build, run: bun `./build.ts bundle`");
      console.log("To run, run: bun `./build.ts run`");
      console.log("To test, run: bun `./build.ts test`");
      console.log("To check, run: bun `./build.ts check`");
      console.log("To clean, run: bun `./build.ts clean`");
      console.log("To format, run: bun `./build.ts fmt`");
      console.log(
          "To run gleam commands on one or both ends, run: bun `./build.ts [client-|server-]gleam <subcommand>`",
      );
    }
}
process.exit(0)
export {};
