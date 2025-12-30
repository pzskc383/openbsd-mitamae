module MItamae
  class Node
    alias orig_initialize initialize

    def initialize(hash, backend)
      orig_initialize(hash, backend)
      backend.node = self
    end
  end
end

module MItamae
  class Backend
    attr_accessor :node

    private

    def build_command(command, _user: nil, cwd: nil)
      command = Shellwords.shelljoin(command) if command.is_a?(Array)
      command = "cd #{cwd.shellescape} && #{command}" if cwd
      command
    end
  end
end
