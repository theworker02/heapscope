# frozen_string_literal: true

module HeapScope
  module Runtime
    # Windows working-set size via PowerShell (no native gem required).
    # Optionally uses stdlib Fiddle when already loaded / available without warnings noise.
    module WindowsRSS
      module_function

      def working_set_bytes
        powershell_working_set_bytes || fiddle_working_set_bytes
      end

      def powershell_working_set_bytes
        out = `powershell -NoProfile -Command "(Get-Process -Id #{Process.pid}).WorkingSet64"`.to_s.strip
        return nil if out.empty?

        Integer(out)
      rescue StandardError
        nil
      end

      def fiddle_working_set_bytes
        return nil unless Object.const_defined?(:Fiddle)

        require "fiddle/import"
        api.working_set_bytes
      rescue StandardError
        nil
      end

      def api
        @api ||= build_api
      end

      def build_api
        Module.new do
          extend Fiddle::Importer

          dlload "kernel32.dll", "psapi.dll"
          typealias "DWORD", "unsigned long"
          typealias "HANDLE", "void*"
          typealias "SIZE_T", "size_t"
          typealias "BOOL", "int"

          const_set(
            :Counters,
            struct([
                     "DWORD cb",
                     "DWORD PageFaultCount",
                     "SIZE_T PeakWorkingSetSize",
                     "SIZE_T WorkingSetSize",
                     "SIZE_T QuotaPeakPagedPoolUsage",
                     "SIZE_T QuotaPagedPoolUsage",
                     "SIZE_T QuotaPeakNonPagedPoolUsage",
                     "SIZE_T QuotaNonPagedPoolUsage",
                     "SIZE_T PagefileUsage",
                     "SIZE_T PeakPagefileUsage"
                   ])
          )

          extern "HANDLE GetCurrentProcess()"
          extern "BOOL GetProcessMemoryInfo(HANDLE, void*, DWORD)"

          define_singleton_method(:working_set_bytes) do
            counters = const_get(:Counters).malloc
            counters.cb = const_get(:Counters).size
            ok = GetProcessMemoryInfo(GetCurrentProcess(), counters, counters.cb)
            ok.zero? ? nil : counters.WorkingSetSize
          end
        end
      end
    end
  end
end
