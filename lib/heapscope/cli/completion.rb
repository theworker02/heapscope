# frozen_string_literal: true

module HeapScope
  class CLI
    # Shell completion script generators (local; no network).
    module Completion
      NAMES = Help::COMMANDS.keys.freeze

      module_function

      def generate(shell)
        case shell.to_s.downcase
        when "bash" then bash
        when "zsh" then zsh
        when "powershell", "pwsh" then powershell
        else
          raise ArgumentError, "unsupported shell: #{shell} (bash|zsh|powershell)"
        end
      end

      def bash
        list = NAMES.join(" ")
        <<~BASH
          # heapscope bash completion — eval "$(heapscope completion bash)"
          _heapscope() {
            local cur="${COMP_WORDS[COMP_CWORD]}"
            if [[ ${COMP_CWORD} -eq 1 ]]; then
              COMPREPLY=( $(compgen -W "#{list}" -- "$cur") )
            else
              COMPREPLY=( $(compgen -f -- "$cur") )
            fi
          }
          complete -F _heapscope heapscope
        BASH
      end

      def zsh
        descriptions = NAMES.map do |n|
          desc = Help::COMMANDS[n].to_s.tr("'", " ")
          "'#{n}:#{desc}'"
        end.join(" ")
        <<~ZSH
          # heapscope zsh completion — eval "$(heapscope completion zsh)"
          _heapscope() {
            local -a cmds
            cmds=(#{descriptions})
            if (( CURRENT == 2 )); then
              _describe 'command' cmds
            else
              _files
            fi
          }
          compdef _heapscope heapscope
        ZSH
      end

      def powershell
        list = NAMES.map { |n| "'#{n}'" }.join(", ")
        <<~PS
          # heapscope PowerShell completion — heapscope completion powershell | Out-String | Invoke-Expression
          Register-ArgumentCompleter -CommandName heapscope -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $commands = @(#{list})
            $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
              [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
          }
        PS
      end
    end
  end
end
