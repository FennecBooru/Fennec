# frozen_string_literal: true

module Middleware
  # A bare html page for middleware responses, in the base theme's colors since the site's styles aren't loaded
  module PlainPage
    module_function

    # body is html, escape anything from outside
    def render(title, body)
      <<~HTML
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="dark">
        <title>#{ERB::Util.html_escape(title)}</title>
        <style>
          body { margin: 0; background: #000; color: #fff; font-family: Verdana, Helvetica, sans-serif; }
          main { max-width: 40em; margin: 4em auto; padding: 1em 1.5em; background: #222; border-radius: 6px; }
          h1 { font-size: 1.5em; margin-top: 0.5em; }
          a { color: #b4c7d9; }
          a:hover { color: #e9f2fa; }
        </style>
        </head>
        <body><main><h1>#{ERB::Util.html_escape(title)}</h1>#{body}</main></body>
        </html>
      HTML
    end
  end
end
