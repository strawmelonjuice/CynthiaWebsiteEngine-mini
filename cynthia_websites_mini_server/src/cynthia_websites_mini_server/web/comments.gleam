import bungibindies/bun
import bungibindies/bun/sqlite
import gleam/json
import plinth/node/process

type CommentType {
  CommentType(
    // Common to all content
    title: String,
    comment: String,
    post_permalink: String,
  )
}

fn encode_comment_type(comment_type: CommentType) -> json.Json {
  json.object([
    #("title", json.string(comment_type.title)),
    #("comment", json.string(comment_type.comment)),
    #("post_permalink", json.string(comment_type.post_permalink)),
  ])
}

fn encode_comment_type_list(comments: List(CommentType)) -> json.Json {
  json.array(comments, encode_comment_type)
}

pub fn periodic_write_to_file(db: sqlite.Database) {
  let assert Ok(res) = {
    // Fetch from db
    // TODO: Implement this with actual data
    Ok([
      CommentType(
        title: "My first comment",
        comment: "This is my first comment!",
        post_permalink: "my-first-post",
      ),
      CommentType(
        title: "My second comment",
        comment: "This is my second comment!",
        post_permalink: "my-second-post",
      ),
    ])
  }
  let jsonstring =
    res
    |> encode_comment_type_list()
    |> json.to_string()
  bun.file(process.cwd() <> "/comments.json")
  |> bun.write(jsonstring)
}
