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
      if (m = output.match(/```json\s*(\{.*?\})\s*```/m))
        json_str = m[1]
        return json_str if valid_top?(json_str)
      end
      nil
    end

    def line_json(output)
      output.each_line do |line|
        s = line.strip
        next if s.empty?
        next unless s.start_with?("{") && s.include?("}")
        return s if valid_top?(s)
      end
      nil
    end

    def balanced_json(output)
      start = output.index("{")
      return nil unless start
      brace = 0
      in_str = false
      esc = false
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
            js = output[start..start + i]
            return js if valid_top?(js)
          end
        end
      end
      nil
    end

    def valid_top?(json_str)
      parsed = JSON.parse(json_str)
      parsed.is_a?(Hash) && parsed.key?("file")
    rescue JSON::ParserError
      false
    end
  end
end
