import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}

pub type SharedCynthiaConfig {
  SharedCynthiaConfig(
    global_theme: String,
    global_theme_dark: String,
    global_colour: String,
    global_site_name: String,
    global_site_description: String,
    server_port: Option(Int),
    server_host: Option(String),
    posts_comments: Bool,
    content: List(Contents),
  )
}

pub type SharedCynthiaConfigGlobalOnly {
  SharedCynthiaConfigGlobalOnly(
    global_theme: String,
    global_theme_dark: String,
    global_colour: String,
    global_site_name: String,
    global_site_description: String,
    server_port: Option(Int),
    server_host: Option(String),
    posts_comments: Bool,
  )
}

pub fn shared_cynthia_config_global_only_decoder() -> decode.Decoder(
  SharedCynthiaConfigGlobalOnly,
) {
  use global_theme <- decode.field("global_theme", decode.string)
  use global_theme_dark <- decode.field("global_theme_dark", decode.string)
  use global_colour <- decode.field("global_colour", decode.string)
  use global_site_name <- decode.field("global_site_name", decode.string)
  use global_site_description <- decode.field(
    "global_site_description",
    decode.string,
  )
  use server_port <- decode.field("server_port", decode.optional(decode.int))
  use server_host <- decode.field("server_host", decode.optional(decode.string))
  use posts_comments <- decode.field(
    "posts_comments",
    decode.optional(decode.bool),
  )
  let posts_comments = posts_comments |> option.unwrap(False)
  decode.success(SharedCynthiaConfigGlobalOnly(
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

pub const default_shared_cynthia_config_global_only: SharedCynthiaConfigGlobalOnly = SharedCynthiaConfigGlobalOnly(
  global_theme: "autumn",
  global_theme_dark: "night",
  global_colour: "#FFFFFF",
  global_site_name: "My Site",
  global_site_description: "A big site on a mini Cynthia!",
  server_port: None,
  server_host: None,
  posts_comments: False,
)

pub fn shared_merge_shared_cynthia_config(
  orig: SharedCynthiaConfigGlobalOnly,
  content: List(Contents),
) -> SharedCynthiaConfig {
  SharedCynthiaConfig(
    global_theme: orig.global_theme,
    global_theme_dark: orig.global_theme_dark,
    global_colour: orig.global_colour,
    global_site_name: orig.global_site_name,
    global_site_description: orig.global_site_description,
    server_port: orig.server_port,
    server_host: orig.server_host,
    posts_comments: orig.posts_comments,
    content:,
  )
}

// And contents
pub type Contents {
  ContentsPage(Page)
  ContentsPost(Post)
}

pub type Page {
  Page(
    // Common to all content
    filename: String,
    title: String,
    description: String,
    layout: String,
    permalink: String,
    // Unique to page
    page: PagePageData,
  )
}

/// Data unique to page type content
pub type PagePageData {
  ContentsPagePageData(menus: List(Int))
}

pub fn page_decoder(filename) -> decode.Decoder(Page) {
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use layout <- decode.field("layout", decode.string)
  use permalink <- decode.field("permalink", decode.string)
  use page <- decode.field(
    "page",
    fn() -> decode.Decoder(PagePageData) {
      use menus <- decode.field("menus", decode.list(decode.int))
      decode.success(ContentsPagePageData(menus:))
    }(),
  )
  decode.success(Page(
    filename:,
    title:,
    description:,
    layout:,
    permalink:,
    page:,
  ))
}

pub type Post {
  Post(
    // Common to all content
    filename: String,
    title: String,
    description: String,
    layout: String,
    permalink: String,
    // Unique to post
    post: PostMetaData,
  )
}

/// Data unique to post type content
pub type PostMetaData {
  PostMetaData(
    /// Date in the  ISO 8601 date format (EG: 2025-01-22T12:12:07+0000)
    date_posted: String,
    /// Date in the  ISO 8601 date format (EG: 2025-01-22T12:12:07+0000)
    date_updated: String,
    /// Category this post belongs to
    category: String,
    /// Tags that belong to this post
    tags: List(String),
  )
}

pub fn post_decoder(filename) -> decode.Decoder(Post) {
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use layout <- decode.field("layout", decode.string)
  use permalink <- decode.field("permalink", decode.string)
  use post <- decode.field(
    "post",
    fn() -> decode.Decoder(PostMetaData) {
      use date_posted <- decode.field("date-posted", decode.string)
      use date_updated <- decode.field("date-updated", decode.string)
      use category <- decode.field("category", decode.string)
      use tags <- decode.field("tags", decode.list(decode.string))
      decode.success(PostMetaData(date_posted:, date_updated:, category:, tags:))
    }(),
  )
  decode.success(Post(
    filename:,
    title:,
    description:,
    layout:,
    permalink:,
    post:,
  ))
}
