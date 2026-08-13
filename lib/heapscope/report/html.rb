# frozen_string_literal: true

require "json"

module HeapScope
  class Report
    # Static HTML report — no backend required. Charts use inline SVG sparkline bars.
    module HTML
      module_function

      def render(report)
        data = report.to_h
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>HeapScope Report — #{escape(report.summary[:healthy] ? "HEALTHY" : "ATTENTION")}</title>
            <style>
              :root {
                --bg0: #f4f7f6;
                --bg1: #e8eef0;
                --ink: #14201c;
                --muted: #5b6b66;
                --accent: #0f766e;
                --accent2: #334155;
                --card: #ffffffcc;
                --high: #b91c1c;
                --med: #c2410c;
                --low: #57534e;
                --ok: #047857;
              }
              * { box-sizing: border-box; }
              body {
                margin: 0;
                font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
                color: var(--ink);
                background:
                  radial-gradient(1200px 600px at 10% -10%, #ccfbf1 0%, transparent 55%),
                  radial-gradient(900px 500px at 100% 0%, #e2e8f0 0%, transparent 50%),
                  linear-gradient(165deg, var(--bg0), var(--bg1));
                min-height: 100vh;
              }
              header.hero {
                padding: 2.5rem 1.25rem 1.5rem;
                max-width: 1040px;
                margin: 0 auto;
                display: grid;
                grid-template-columns: 72px 1fr;
                gap: 1.25rem;
                align-items: center;
              }
              header.hero svg { width: 72px; height: 72px; }
              h1 {
                font-family: "IBM Plex Serif", Georgia, serif;
                font-weight: 650;
                letter-spacing: -0.03em;
                font-size: clamp(2rem, 4vw, 2.75rem);
                margin: 0;
              }
              .tagline { color: var(--muted); margin: 0.35rem 0 0; }
              main { max-width: 1040px; margin: 0 auto; padding: 0 1.25rem 4rem; }
              .banner {
                padding: 1rem 1.25rem;
                background: var(--card);
                backdrop-filter: blur(8px);
                border-left: 5px solid var(--accent);
                border-radius: 0 12px 12px 0;
                margin: 1rem 0 1.5rem;
              }
              .banner.ok { border-left-color: var(--ok); }
              .banner.warn { border-left-color: var(--med); }
              h2 {
                margin-top: 2.25rem;
                font-size: 0.85rem;
                color: var(--accent);
                text-transform: uppercase;
                letter-spacing: 0.08em;
              }
              .grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
                gap: 0.75rem;
              }
              .stat {
                background: var(--card);
                border-radius: 12px;
                padding: 1rem;
                border: 1px solid #d6e0dc;
              }
              .stat .label { font-size: 0.75rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
              .stat .value { font-size: 1.35rem; font-weight: 600; margin-top: 0.25rem; }
              table { width: 100%; border-collapse: collapse; background: var(--card); border-radius: 12px; overflow: hidden; }
              th, td { text-align: left; padding: 0.55rem 0.7rem; border-bottom: 1px solid #e4ebe8; font-size: 0.92rem; }
              th { background: #f0f5f3; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.04em; color: var(--muted); }
              .sev-high { color: var(--high); font-weight: 650; }
              .sev-medium { color: var(--med); font-weight: 600; }
              .sev-low { color: var(--low); }
              .bars { display: flex; align-items: flex-end; gap: 3px; height: 48px; margin: 0.5rem 0 1rem; }
              .bars span {
                display: block;
                width: 10px;
                background: linear-gradient(180deg, #2dd4bf, #0f766e);
                border-radius: 3px 3px 0 0;
                min-height: 2px;
              }
              pre {
                background: #0f172a;
                color: #e2e8f0;
                padding: 1rem;
                overflow: auto;
                font-size: 0.78rem;
                border-radius: 12px;
                max-height: 420px;
              }
              .note { font-size: 0.85rem; color: var(--muted); }
              footer { margin-top: 3rem; color: var(--muted); font-size: 0.85rem; }
              @media (max-width: 640px) {
                header.hero { grid-template-columns: 1fr; }
              }
            </style>
          </head>
          <body>
            <header class="hero">
              #{logo_svg}
              <div>
                <h1>HeapScope</h1>
                <p class="tagline">Retention-first diagnostics · v#{escape(report.heapscope_version)} · Ruby #{escape(report.runtime_info[:ruby])} · schema #{report.schema_version}</p>
              </div>
            </header>
            <main>
              <div class="banner #{report.summary[:healthy] ? "ok" : "warn"}">
                <strong>#{report.summary[:healthy] ? "HEALTHY" : "ATTENTION"}</strong>
                <div class="note">#{escape(Scorecard.from_report(report).to_text.lines[2..5]&.join(' ') || 'Estimates are approximate.')}</div>
                <div class="note">Object values are not included by default. Facts ≠ hypotheses.</div>
              </div>

              <h2>Memory overview</h2>
              <div class="grid">
                <div class="stat"><div class="label">RSS before</div><div class="value">#{bytes(report.before&.rss_bytes)}</div></div>
                <div class="stat"><div class="label">RSS after</div><div class="value">#{bytes(report.after&.rss_bytes)}</div></div>
                <div class="stat"><div class="label">RSS Δ</div><div class="value">#{bytes(report.diff&.rss_delta)}</div></div>
                <div class="stat"><div class="label">Live slots Δ</div><div class="value">#{report.diff&.heap_live_delta || "n/a"}</div></div>
                <div class="stat"><div class="label">Retention</div><div class="value">#{ratio(report.diff&.retention_ratio)}</div></div>
                <div class="stat"><div class="label">Findings</div><div class="value">#{report.findings.size}</div></div>
              </div>

              #{sparkline_section(report)}

              <h2>Top class growth</h2>
              <table>
                <tr><th>Class</th><th>Before</th><th>After</th><th>Delta</th><th>Bytes Δ</th></tr>
                #{class_rows(report)}
              </table>

              <h2>Top suspects</h2>
              #{suspect_blocks(report)}

              <h2>Findings</h2>
              #{finding_blocks(report)}

              <h2>Next steps</h2>
              #{next_step_blocks(report)}

              <h2>Limitations</h2>
              <p class="note">#{report.limitations.empty? ? "None recorded." : escape(report.limitations.join(", "))}</p>

              <h2>Raw JSON</h2>
              <pre>#{escape(JSON.pretty_generate(data))}</pre>

              <footer>
                #{Branding.html_footer}
              </footer>
            </main>
          </body>
          </html>
        HTML
      end

      def logo_svg
        inline = Branding.logo_svg_inline
        return inline if inline && !inline.strip.empty?

        <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" aria-hidden="true">
            <defs>
              <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stop-color="#0f766e"/><stop offset="100%" stop-color="#334155"/>
              </linearGradient>
            </defs>
            <rect width="256" height="256" rx="48" fill="url(#bg)"/>
            <rect x="52" y="150" width="36" height="36" rx="4" fill="#5eead4"/>
            <rect x="94" y="132" width="36" height="54" rx="4" fill="#99f6e4"/>
            <rect x="136" y="114" width="36" height="72" rx="4" fill="#ccfbf1"/>
            <circle cx="156" cy="96" r="42" fill="none" stroke="#ecfdf5" stroke-width="14"/>
            <line x1="186" y1="126" x2="214" y2="154" stroke="#ecfdf5" stroke-width="14" stroke-linecap="round"/>
          </svg>
        SVG
      end

      def next_step_blocks(report)
        steps = Suggest.next_steps(report)
        return "<p class='note'>No prioritized next steps.</p>" if steps.empty?

        items = steps.map.with_index do |step, i|
          tag = step[:code] ? escape(step[:code]) : "hint"
          "<li><strong>#{i + 1}. [#{tag}]</strong> #{escape(step[:action])}</li>"
        end.join
        "<ol>#{items}</ol>"
      end

      def sparkline_section(report)
        series = report.retention && report.retention[:class_series]
        return "" unless series && !series.empty?

        top = series.first
        vals = Array(top[:series]).map(&:to_f)
        return "" if vals.empty?

        max = vals.max.nonzero? || 1
        bars = vals.map { |v| "<span style='height:#{[(v / max * 48).round, 2].max}px'></span>" }.join
        <<~HTML
          <h2>Retention sparkline — #{escape(top[:name])}</h2>
          <div class="bars">#{bars}</div>
          <p class="note">Sample series: #{escape(vals.map(&:to_i).inspect)} · pattern #{escape(top.dig(:trend, :pattern).to_s)}</p>
        HTML
      end

      def class_rows(report)
        rows = report.diff ? report.diff.growing_classes(20) : []
        return "<tr><td colspan='5'>No growth data</td></tr>" if rows.empty?

        rows.map do |c|
          "<tr><td>#{escape(c[:name])}</td><td>#{c[:before_count]}</td><td>#{c[:after_count]}</td>" \
            "<td>#{c[:delta_count]}</td><td>#{bytes(c[:delta_bytes])}</td></tr>"
        end.join("\n")
      end

      def suspect_blocks(report)
        return "<p class='note'>No ranked suspects.</p>" if report.suspects.empty?

        rows = report.suspects.first(10).map.with_index do |s, i|
          "<tr><td>#{i + 1}</td><td>#{escape(s[:name])}</td>" \
            "<td class='sev-#{s[:severity]}'>#{s[:severity].to_s.upcase}</td>" \
            "<td>+#{s[:delta_count]}</td><td>#{escape(s[:classification].to_s)}</td></tr>"
        end.join
        "<table><tr><th>#</th><th>Class</th><th>Severity</th><th>Delta</th><th>Class</th></tr>#{rows}</table>"
      end

      def finding_blocks(report)
        return "<p class='note'>No findings.</p>" if report.findings.empty?

        report.findings.map do |f|
          <<~BLOCK
            <div class="banner">
              <div class="sev-#{f.severity}">#{f.code} — #{escape(f.title)}</div>
              <ul>#{f.facts.map { |x| "<li>#{escape(x)}</li>" }.join}</ul>
              #{f.hypothesis ? "<p>#{escape(f.hypothesis)}</p>" : ""}
              #{f.suspected_cause ? "<p class='note'>Suspected cause: #{escape(f.suspected_cause)}</p>" : ""}
            </div>
          BLOCK
        end.join
      end

      def bytes(n)
        return "n/a" if n.nil?

        format("%.2f MB", n.to_f / (1024 * 1024))
      end

      def ratio(n)
        return "n/a" if n.nil?

        format("%.2f%%", n * 100.0)
      end

      def escape(str)
        str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end
    end
  end
end
