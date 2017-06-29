module Erbse
  class Parser
    # ERB_EXPR = /<%(=|\#)?(.*?)%>(\n)*/m # this is the desired pattern.
    ERB_EXPR = /<%(=+|-|\#|@\s|%)?(.*?)[-=]?%>(\n*)/m # this is for backward-compatibility.
    # BLOCK_EXPR     = /\s*((\s+|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/
    BLOCK_EXPR = /\b(if|unless)\b|\sdo\s*$|\sdo\s+\|/

    # Parsing patterns
    #
    # Blocks will be recognized when written:
    # <% ... do %> or <% ... do |...| %>

    def initialize(*)
    end

    def call(str)
      pos = 0
      buffers = []
      result = [:multi]
      buffers << result
      match = nil

      str.scan(ERB_EXPR) do |indicator, code, newlines|
        match = Regexp.last_match
        len = match.begin(0) - pos

        text = str[pos, len]
        pos = match.end(0)
        ch = indicator ? indicator[0] : nil
        if text and !text.strip.empty? # text
          buffers.last << [:static, text]
        end

        if ch == ?= # <%= %>
          if code =~ BLOCK_EXPR
            buffers.last << [:erb, :block, code, block = [:multi]] # picked up by our own BlockFilter.
            buffers << block
          else
            buffers.last << [:dynamic, code]
          end
        elsif ch =~ /#/ # DISCUSS: doesn't catch <% # this %>
          _newlines = code.count("\n")
          buffers.last.concat [[:newline]] * _newlines if _newlines > 0
        elsif code =~ /\bend\b/ # <% end %>
          buffers.pop
        elsif ch == ?@
          buffers.last << [:capture, :block, code, block = [:multi]] # picked up by our own BlockFilter. # TODO: merge with %= ?
          buffers << block
        else # <% %>
          if code =~ BLOCK_EXPR
            buffers.last << [:block, code, block = [:multi]] # picked up by Temple's ControlFlow filter.
            buffers << block
          else
            buffers.last << [:code, code]
          end
        end

        # FIXME: only adds one newline.
        # TODO: does that influence speed?
        if !newlines.empty? && newlines.count("\n") > 0
          (1..newlines.count("\n")).each do
            buffers.last << [:static, "\n"]
            buffers.last << [:newline]
          end
        end
      end

      # add text after last/none ERB tag.
      buffers.last << [:static, str[pos..str.length]] if pos < str.length

      buffers.last
    end
  end
end
