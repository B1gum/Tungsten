local stub = require("luassert.stub")
local match = require("luassert.match")
local async = require("tungsten.util.async")

describe("PersistentJob", function()
	local mock_job
	local mock_job_new

	before_each(function()
		mock_job = {
			start = stub(),
			send = stub(),
			shutdown = stub(),
		}

		local plenary_job = require("plenary.job")
		mock_job_new = stub(plenary_job, "new", function(_, opts)
			mock_job._on_stdout = opts.on_stdout
			return mock_job
		end)
	end)

	after_each(function()
		if mock_job_new then mock_job_new:revert() end
	end)

	it("creates a job with the correct command", function()
		async.create_persistent_job({ "python3", "-u" }, { delimiter = "END" })

		assert.stub(mock_job_new).was_called_with(match.is_table(), match.is_table())
		assert.stub(mock_job.start).was_called()
	end)

	it("queues commands and sends them sequentially", function()
		local job = async.create_persistent_job({ "cmd" }, {})

		job.ready = true

		local callback1 = stub()
		job:send("1+1", callback1)

		assert.stub(mock_job.send).was_called_with(mock_job, "1+1\n")

		local callback2 = stub()
		job:send("2+2", callback2)

		assert.stub(mock_job.send).was_called(1)

		mock_job._on_stdout(nil, "2")
		mock_job._on_stdout(nil, "__TUNGSTEN_END__")

		vim.wait(10)
		assert.stub(callback1).was_called_with("2", nil)

		assert.stub(mock_job.send).was_called_with(mock_job, "2+2\n")
	end)

	it("handles initialization (skips first callback)", function()
		local job = async.create_persistent_job({ "cmd" }, {})

		local init_cb = stub()
		job:send("import foo", init_cb)

		mock_job._on_stdout(nil, "Banner Info")
		mock_job._on_stdout(nil, "__TUNGSTEN_END__")

		vim.wait(10)
		assert.is_true(job.ready)

		local next_cb = stub()
		job:send("real work", next_cb)
		assert.stub(mock_job.send).was_called_with(mock_job, "real work\n")
	end)
end)
