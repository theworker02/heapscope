# frozen_string_literal: true

module HeapScope
  # Central brand + funding metadata for CLI, reports, and docs generation.
  module Branding
    NAME = "HeapScope"
    TAGLINE = "Ruby retention & heap growth diagnostics"
    GITHUB_USER = "theworker02"
    GITHUB_REPO = "https://github.com/theworker02/heapscope"
    PAGES_URL = "https://theworker02.github.io/heapscope/"
    SPONSORS_URL = "https://github.com/sponsors/theworker02"
    THANKS_DEV_URL = "https://thanks.dev/u/gh/theworker02"
    THANKS_DEV_PATH = "u/gh/theworker02"
    LOGO_SVG = "assets/logo.svg"
    WORDMARK_SVG = "assets/wordmark.svg"
    LOGO_PNG = "assets/heapscope-logo.png"

    module_function

    def banner
      <<~BANNER
        ██╗  ██╗███████╗ █████╗ ██████╗ ███████╗ ██████╗ ██████╗ ██████╗ ███████╗
        ██║  ██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔═══██╗██╔══██╗██╔════╝
        ███████║█████╗  ███████║██████╔╝███████╗██║     ██║   ██║██████╔╝█████╗
        ██╔══██║██╔══╝  ██╔══██║██╔═══╝ ╚════██║██║     ██║   ██║██╔═══╝ ██╔══╝
        ██║  ██║███████╗██║  ██║██║     ███████║╚██████╗╚██████╔╝██║     ███████╗
        ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚══════╝
        #{TAGLINE}  v#{VERSION}
      BANNER
    end

    def compact_banner
      "#{NAME} v#{VERSION} — #{TAGLINE}"
    end

    def funding_lines
      [
        "Sponsor: #{SPONSORS_URL}",
        "thanks.dev: #{THANKS_DEV_URL}",
        "Docs site: #{PAGES_URL}"
      ]
    end

    def about_text
      lines = []
      lines << compact_banner
      lines << ""
      lines << "Repository: #{GITHUB_REPO}"
      lines << "Website:    #{PAGES_URL}"
      funding_lines.each { |l| lines << l }
      lines << ""
      lines << "Privacy: local-only diagnostics — no telemetry, no object-value dumps by default."
      lines.join("\n")
    end

    def report_footer
      "Privacy: object values are not serialized by default. · #{THANKS_DEV_URL} · #{PAGES_URL}"
    end

    def html_footer
      "Generated locally by #{NAME} · no network · no telemetry · " \
        "<a href=\"#{THANKS_DEV_URL}\">thanks.dev</a> · " \
        "<a href=\"#{PAGES_URL}\">docs</a>"
    end

    def gem_root
      File.expand_path("../..", __dir__)
    end

    def asset_path(relative)
      File.join(gem_root, relative)
    end

    def logo_svg_inline
      path = asset_path(LOGO_SVG)
      return nil unless File.file?(path)

      File.read(path)
    end

    def to_h
      {
        name: NAME,
        tagline: TAGLINE,
        version: VERSION,
        github_user: GITHUB_USER,
        github_repo: GITHUB_REPO,
        pages_url: PAGES_URL,
        sponsors_url: SPONSORS_URL,
        thanks_dev_url: THANKS_DEV_URL,
        thanks_dev_path: THANKS_DEV_PATH,
        logo_svg: LOGO_SVG,
        wordmark_svg: WORDMARK_SVG,
        logo_png: LOGO_PNG
      }
    end
  end
end
