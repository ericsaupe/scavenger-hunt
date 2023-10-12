# frozen_string_literal: true

module ResultsHelper
  def results_text_size(index)
    case index
    when 0
      "text-xl"
    when 1
      "text-lg"
    else
      "text-md"
    end
  end
end
