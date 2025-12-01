local M = {}

function M.to_siunitx(text)
	if not text or text == "" then
		return text
	end

	local clean = text:match("^%s*(.-)%s*$")

	local ang_val = clean:match("^([%-?%d%.]+)%s*[\\%^]+{?%\\circ}?$")
	if ang_val then
		return string.format("\\ang{%s}", ang_val)
	end

	local val, unit = clean:match("^([%-?%d%.]+)%s*[\\%s]+text{([a-zA-Z]+)}$")
	if not val then
		val, unit = clean:match("^([%-?%d%.]+)%s*[\\%s]+mathrm{([a-zA-Z]+)}$")
	end
	if not val then
		val, unit = clean:match("^([%-?%d%.]+)%s+([a-zA-Z]+)$")
	end

	if val and unit then
		return string.format("\\qty{%s}{%s}", val, unit)
	end

	return text
end

return M
