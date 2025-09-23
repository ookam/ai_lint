require "json"

module AiLint
  module JSONExtract
    module_function

    def from_output(output)
      return nil if output.nil? || output.strip.empty?
      fence = fenced_json(output)
      return fence if fence
      line = line_json(output)
      return line if line
      balanced_json(output)
    end

    def fenced_json(output)
      last = nil
      output.scan(/```json\s*(\{.*?\})\s*```/m) do |m|
        json_str = m[0]
        last = json_str if valid_top?(json_str)
      end
      last
    end

    def line_json(output)
      last = nil
      output.each_line do |line|
        s = line.strip
        next if s.empty?
        next unless s.start_with?("{") && s.include?("}")
        last = s if valid_top?(s)
      end
      last
    end

    def balanced_json(output)
      last = nil
      from = 0
      while (start = output.index("{", from))
        brace = 0
        in_str = false
        esc = false
        end_idx = nil
        output[start..-1].each_char.with_index do |ch, i|
          if esc
            esc = false
            next
          end
          if ch == "\\"
            esc = true
            next
          end
          if ch == '"'
            in_str = !in_str
          end
          unless in_str
            brace += 1 if ch == '{'
            brace -= 1 if ch == '}'
            if brace == 0
              end_idx = start + i
              break
            end
          end
        end
        if end_idx
          js = output[start..end_idx]
          last = js if valid_top?(js)
        end
        from = start + 1
      end
      last
    end

    def valid_top?(json_str)
      parsed = JSON.parse(json_str)
      return false unless parsed.is_a?(Hash)
      file = parsed["file"]
      status = parsed["status"]
      messages = parsed["messages"]

      return false unless file.is_a?(String) && !file.strip.empty?
      return false unless %w[ok ng].include?(status)
      return false unless messages.is_a?(Array)
      return false if messages.length == 1 && messages[0].is_a?(String) && messages[0].strip == "..."
      true
    rescue JSON::ParserError
      false
    end
  end
end
