function load_ijulia_handlers()
    themodule = eval(:(Main.IJulia))
    Core.eval(themodule, handler_code)
end

handler_code = quote
struct JupyterMode
    code
    helpcode
    output
end

# Make this mutable to avoid 
#JupyterMode() = JupyterMode(identity, identity, identity)

#default_help_hook(hcode) = Core.eval(Main, REPL.helpmode(hcode))  # helpcode

const default_mode = JupyterMode(
    identity,   # code
    (hcode) -> Core.eval(Main, REPL.helpmode(hcode)),  # helpcode
    identity  # output
)

const ijulia_modes = Dict()

function install_ijulia_mode(modename::Symbol, mode::JupyterMode)
    ijulia_modes[modename] = mode
end

install_ijulia_mode(:default, default_mode)

const current_mode = Ref(default_mode)
function set_ijulia_mode(modename::Symbol)
    if ! haskey(ijulia_modes, modename)
        throw(KeyError(modename))
    end
    current_mode[] = ijulia_modes[modename]
end
#set_ijulia_mode(:default) # redundant, but signals

function set_handler(handlername, handlerfunction)
    handlername_string = String(handlername)
    if ! haskey(handlers, handlername_string)
        throw(KeyError(handlername_string))
    end
    handlers[String(handlername)] = handlerfunction
end

# const symata_mode = JupyterMode(
#     code -> "@Symata.ex " * " begin\n" * code * "\nend",  # begin end to wrap multi-expression input
#     helpcode -> "Help(" * strip(helpcode)[2:end] * ")",
#     symata_format_output
# )
# install_ijulia_mode(:symata, symata_mode)
# set_ijulia_mode(:symata)

function execute_request_modal(socket, msg)
    code = msg.content["code"]
    @vprintln("EXECUTING ", code)
    global execute_msg = msg
    global n, In, Out, ans
    stdio_bytes[] = 0
    silent = msg.content["silent"]
    store_history = get(msg.content, "store_history", !silent)
    empty!(execute_payloads)

    if !silent
        n += 1
        send_ipython(publish[],
                     msg_pub(msg, "execute_input",
                             Dict("execution_count" => n,
                                          "code" => code)))
    end

    silent = silent || REPL.ends_with_semicolon(code)
    if store_history
        In[n] = code
    end

    # "; ..." cells are interpreted as shell commands for run
    code = replace(code, r"^\s*;.*$" =>
                   m -> string(replace(m, r"^\s*;", "Base.repl_cmd(`"),
                               "`, ", stdout_name, ")"))

    # a cell beginning with "? ..." is interpreted as a help request
    hcode = replace(code, r"^\s*\?" => "")

    try
        for hook in preexecute_hooks
            invokelatest(hook)
        end


        if hcode != code # help request
            current_mode[].help(hcode)
        else
            #run the code!
            code = current_mode[].code(code)
            ans = result = occursin(magics_regex, code) ? magics_help(code) :
                include_string(current_module[], code, "In[$n]")
        end

        if silent
            result = nothing
        elseif result !== nothing
            if store_history
                Out[n] = result
            end
        end

        user_expressions = Dict()
        for (v,ex) in msg.content["user_expressions"]
            user_expressions[v] = invokelatest(parse, ex)
        end

        for hook in postexecute_hooks
            invokelatest(hook)
        end

        # flush pending stdio
        flush_all()

        undisplay(result) # dequeue if needed, since we display result in pyout
        invokelatest(display) # flush pending display requests

        if result !== nothing
            result_metadata = invokelatest(metadata, result)
            result_data = invokelatest(display_dict, current_mode[].output(result))
            send_ipython(publish[],
                         msg_pub(msg, "execute_result",
                                 Dict("execution_count" => n,
                                              "metadata" => result_metadata,
                                              "data" => result_data)))

        end
        send_ipython(requests[],
                     msg_reply(msg, "execute_reply",
                               Dict("status" => "ok",
                                            "payload" => execute_payloads,
                                            "execution_count" => n,
                                            "user_expressions" => user_expressions)))
        empty!(execute_payloads)
    catch e
        bt = catch_backtrace()
        try
            # flush pending stdio
            flush_all()
            for hook in posterror_hooks
                invokelatest(hook)
            end
        catch
        end
        empty!(displayqueue) # discard pending display requests on an error
        content = error_content(e,bt)
        send_ipython(publish[], msg_pub(msg, "error", content))
        content["status"] = "error"
        content["execution_count"] = n
        send_ipython(requests[], msg_reply(msg, "execute_reply", content))
    end
end

nothing

end # quote
