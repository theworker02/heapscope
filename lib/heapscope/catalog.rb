# frozen_string_literal: true

module HeapScope
  # Catalog of diagnostic codes for CLI / docs generation.
  module Catalog
    module_function

    def codes
      Diagnostics::CODES.values
    end

    def lookup(code)
      key = normalize_code(code)
      Diagnostics::CODES[key]
    end

    def explain(code)
      meta = lookup(code)
      raise ArgumentError, "Unknown diagnostic code: #{code}" unless meta

      doc = encyclopedia_text(meta)
      return doc if doc

      fallback_text(meta)
    end

    def to_text
      lines = [Branding.compact_banner, "", "Diagnostic codes", ""]
      codes.each do |c|
        lines << "#{c[:id]}  #{c[:name]}"
        lines << "      #{c[:title]}  (default severity: #{c[:default_severity]})"
        lines << ""
      end
      lines << Branding.funding_lines.join("\n")
      lines.join("\n")
    end

    def normalize_code(code)
      raw = code.to_s.strip.upcase
      return raw if Diagnostics::CODES.key?(raw)
      return "HS#{raw}" if raw.match?(/\A\d{3}\z/)
      return format("HS%03d", raw.to_i) if raw.match?(/\A\d+\z/)

      raw
    end

    def encyclopedia_path(meta)
      root = File.expand_path("../../..", __dir__)
      File.join(root, "docs", "diagnostics", "#{meta[:id]}_#{meta[:name]}.md")
    end

    def encyclopedia_text(meta)
      path = encyclopedia_path(meta)
      return nil unless File.file?(path)

      File.read(path)
    end

    def fallback_text(meta)
      <<~TEXT
        #{meta[:id]} — #{meta[:name]}
        Title: #{meta[:title]}
        Default severity: #{meta[:default_severity]}

        See docs/diagnostics/#{meta[:id]}_#{meta[:name]}.md when packaged with the gem.
        #{Branding.funding_lines.join("\n")}
      TEXT
    end
    private_class_method :encyclopedia_path, :encyclopedia_text, :fallback_text
  end
end
