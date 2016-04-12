module JSymPy

export sympy2mxpr, mxpr2sympy
export sympy

importall SJulia
import SJulia: mxpr  # we need this even with importall

using PyCall

# With code as it is now, we cannot import or using SymPy
# import SymPy: sympy_meth

# Initial Author: Francesco Bonazzi

## Convert SymPy to Mxpr

# Trying to import these later, via the function. But, no luck
#function import_sympy()
    @pyimport sympy
    @pyimport sympy.core as sympy_core
#end
#import_sympy()

# Some SymPy functions are encoded this way. Others, not. Eg, Add, Mul are different
const SYMPY_TO_SJULIA_FUNCTIONS = Dict{Symbol,Symbol}()
const SJULIA_TO_SYMPY_FUNCTIONS = Dict{Symbol,Symbol}()

# Functions to include
# SineTransform, should be automatically converted, there is also sine_transform
# sympy has erf and erf2. we need to check number of args.

function make_sympy_to_sjulia()
    single_arg_float_complex =
        [ (:sin,), (:cos,), (:tan,), (:sinh,),(:cosh,), (:Si, :SinIntegral), (:Ci, :CosIntegral),
          (:tanh,), (:acos,:ArcCos), (:asin,:ArcSin),(:atan,:ArcTan),(:atan2,:ArcTan2),
         (:sec,),(:csc,),(:cot,), (:exp,), (:sqrt,),(:log,),
         (:asec,:ArcSec),(:acsc,:ArcCsc),(:acot,:ArcCot),
         (:coth,),(:asinh,:ASinh),(:acosh,:ACosh),(:atanh,:ATanh),
         (:acoth,:ArcCoth),
         (:erf,),(:erfc,),(:erfi,),(:re,:Re),(:im,:Im),
         (:arg,:Arg),(:gamma,),(:loggamma,:LogGamma),
         (:digamma,),(:trigamma,),(:polygamma,), (:airyai,:AiryAi),
         (:airybi,:AiryBi),(:airyaiprime,:AiryAiPrime),(:airybiprime,:AiryBiPrime),
         (:besselj,:BesselJ),(:besseli,:BesselI),(:besselk,:BesselK),
         (:zeta,), (:LambertW, :LambertW)
         ]

    single_arg_float_int_complex =
        [
         (:conjugate,)
         ]

    single_arg_float = [(:cbrt,:CubeRoot),(:erfinv,:InverseErf),(:erfcinv,:InverseErfc)
                        ]

    single_arg_float_int = [(:factorial,),(:sign,)]

    single_arg_int = [(:integer_nthroot,:IntegerNthRoot),(:nextprime, :NextPrime), (:prevprime, :PrevPrime),
                      (:isprime,:PrimeQ)
                        ]

    two_arg_int = [(:binomial,)
                   ]

    two_arg_float_and_float_or_complex =
     [
      (:besselj,:BesselJ),(:bessely,:BesselY),
      (:hankel1,:HankelH1),
      (:hankel2,:HankelH2),(:besseli,:BesselI),
      (:besselk,:BesselK)
      ]

     two_arg_float = [ (:beta,)]

    symbolic_misc = [ (:Order, :Order), (:harmonic,), (:laplace_transform, :LaplaceTransform) ]
    
    for funclist in (single_arg_float_complex, single_arg_float_int_complex, single_arg_float,
                     single_arg_float_int, single_arg_int, two_arg_int, two_arg_float_and_float_or_complex, two_arg_float,
                     symbolic_misc)
        for x in funclist
            sympy_func, sjulia_func = SJulia.get_sjstr(x)
            SYMPY_TO_SJULIA_FUNCTIONS[sympy_func] = sjulia_func            
        end
    end
    for (k,v) in SYMPY_TO_SJULIA_FUNCTIONS
        SJULIA_TO_SYMPY_FUNCTIONS[v] = k
    end
end

make_sympy_to_sjulia()

####################


# looks like this is executed at compile time
#function mk_py_to_mx_funcs2()
#    @eval begin     
    # TODO: generate this code, like the functions below
#        const SympySymbol = sympy_core.symbol["Symbol"]
#        const SympyAdd = sympy_core.add["Add"] # test removing
#        const SympyMul = sympy_core.mul["Mul"]
#        const SympyPow = sympy_core.power["Pow"]
        # Following is the strategy that I # TODO: hought of at the very beginning.
        # It seems bassackwards, but it is more general than searching for each
        # peculiar way of encoding a head:
        # 1. a python instance is returned. we have no idea in general how to check
        # other objects for its type.
        # 2. construct an object and find it's type and assign to a constant.
#        const SympyD = pytypeof(sympy_core.Derivative(:x))
#        const Sympyintegrate = sympy.integrals["Integral"]
#        const SympyTuple = sympy.containers["Tuple"]
#        const SympyNumber = sympy_core.numbers["Number"]
#        const SympyPi  = sympy_core.numbers["Pi"]
        # Why did I comment the following out ? It seems to be needed
#        const SympyE  = pytypeof(sympy_core.numbers["E"])
#        const SympyE  = sympy.numbers["Exp1"])        
#        const SympyI  = sympy_core.numbers["ImaginaryUnit"]
#        const SymPyInfinity = sympy.oo
#        const SymPyComplexInfinity = sympy.zoo
#    end
#end
# mk_py_to_mx_funcs2()

#### Convert SymPy to Mxpr

# I don't like the emacs indenting. try to fix this at some point!
# Must populate this dict here. If use only the function
# populate..., then we get test errors. no idea why
const py_to_mx_dict =
    Dict(
         sympy.Add => :Plus,         
         sympy.Mul => :Times,
         sympy.Pow => :Power,
         sympy.Derivative => :D,
         sympy.integrals["Integral"] => :Integrate,
         sympy.containers["Tuple"] => :List,
         sympy.oo => :Infinity,
         sympy.zoo => :ComplexInfinity
         )

function populate_py_to_mx_dict()
    for onepair in (
                    (sympy.Add, :Plus),                    
                    (sympy.Mul, :Times),
         (sympy.Pow ,:Power),
         (sympy.Derivative, :D),
         (sympy.integrals["Integral"], :Integrate),
         (sympy.containers["Tuple"], :List),
         (sympy.oo, :Infinity),
                     (sympy.zoo,:ComplexInfinity))
        py_to_mx_dict[onepair[1]] = onepair[2]
    end
end

populate_py_to_mx_dict()

function mk_py_to_mx_funcs()
    for (pysym,sjsym) in SYMPY_TO_SJULIA_FUNCTIONS
        pystr = string(pysym)
        sjstr = string(sjsym)
        csym = symbol("SymPy" * sjstr)
        @eval begin
            if haskey(sympy.functions, $pystr)
                const $csym = sympy.functions[$pystr]
                py_to_mx_dict[$csym] =  symbol($sjstr)                
            end
        end
    end
end

mk_py_to_mx_funcs()

# I think these are not useful.
const pymx_special_symbol_dict = Dict()
          # SympyPi => :Pi,
          # SympyE => :E,
          # SympyI => complex(0,1)

function populate_special_symbol_dict()
    for onepair in ( 
          (sympy_core.numbers["Pi"], :Pi),
          (sympy.numbers["Exp1"],  :E),
          (sympy_core.numbers["ImaginaryUnit"], complex(0,1)))
        pymx_special_symbol_dict[onepair[1]] = onepair[2]
    end
end

populate_special_symbol_dict()

sympy2mxpr(x) = x

function sympy2mxpr{T <: PyCall.PyObject}(expr::T)
#    println("annot ", typeof(expr), " ",expr )
    if (pytypeof(expr) in keys(py_to_mx_dict))
        return SJulia.mxpr(py_to_mx_dict[pytypeof(expr)], map(sympy2mxpr, expr[:args])...)
    end
    if expr[:is_Function]       # perhaps a user defined function
        # objstr = split(string(pytypeof(expr)))
        # head = symbol(objstr[end])  # The string is "PyObject bb"
        head = symbol(pytypeof(expr)[:__name__])
        return SJulia.mxpr(head, map(sympy2mxpr, expr[:args])...)
    end
    for k in keys(pymx_special_symbol_dict)
        if pyisinstance(expr,k)
            return pymx_special_symbol_dict[k]
        end
    end
#    if pytypeof(expr) == SympySymbol
    if pytypeof(expr) == sympy.Symbol        
        return Symbol(expr[:name])
    end
    if pyisinstance(expr, sympy.Number)
        # Big ints are wrapped up in a bunch of stuff
        # There is a function n._to_mpmath(m) (dont know what m means) that returns GMP number useable by Julia
        # We need to check what kind of integer. searching methods. no luck
        # we could try catch _to_mpmath
        if expr[:is_Integer]
            #  Apparently, if the number is not really a bigint, a machine sized int is actually returned
            #  Yes, tested this with Int64 and GMP ints and the correct thing is returned
            num = expr[:_to_mpmath](-1)  #  works for some numbers at the command line
            return num
        end
        if expr[:is_Rational]
            p = expr[:p]
            q = expr[:q]
            return Rational(expr[:p],expr[:q])  # These are Int64's. Don't know when or if they are BigInts
        end
        return convert(AbstractFloat, expr) # Need to check for big floats
    end
    head = symbol(expr[:func][:__name__])  # Maybe we can move this further up ?
    return SJulia.mxpr(head, map(sympy2mxpr, expr[:args])...)
#    println("sympy2mxpr: Unable to translate ", expr)
#    return expr
end

# By default, Dict goes to Dict
function sympy2mxpr(expr::Dict)
    ndict = Dict()
    for (k,v) in expr
        ndict[sympy2mxpr(k)] = sympy2mxpr(v)
    end
    return ndict
end

function sympy2mxpr{T}(expr::Array{T,1})
    return SJulia.mxpr(:List,map(sympy2mxpr, expr)...)
end



#### Convert Mxpr to SymPy

# These should be generated... And why do we use instances here and classes above ?
# (if that is what is happening. )
const mx_to_py_dict =
    Dict(
         # :Plus => sympy.Add,
         # :Times => sympy.Mul,
         # :Power => sympy.Pow,
         # :E => sympy.E,
         # :I => SympyI,
         # :Pi => sympy.pi,
         # :Log => sympy.log,
         # :Infinity => sympy.oo,
         # :ComplexInfinity => sympy.zoo
         )

function populate_mx_to_py_dict()
    for onepair in ( 
         (:Plus,sympy.Add),
         (:Times, sympy.Mul),
         (:Power, sympy.Pow),
         (:E, sympy.E),
         (:I,sympy_core.numbers["ImaginaryUnit"]),
         (:Pi,  sympy.pi),
#         :Pi => SympyPi,
         (:Log, sympy.log),
         (:Infinity, sympy.oo),
         (:ComplexInfinity, sympy.zoo))
        mx_to_py_dict[onepair[1]] = onepair[2]
    end
end

populate_mx_to_py_dict()


# !!! this overwrites function above. I forgot to change the name
# function mk_py_to_mx_funcs()
#     for (sjsym,pysym) in SJULIA_TO_SYMPY_FUNCTIONS
#         pystr = string(pysym)
#         sjstr = string(sjsym)
#         obj = eval(parse("sympy." * pystr))
#         @eval begin
#             mx_to_py_dict[symbol($sjstr)] = $obj
#         end
#     end
# end

# mk_py_to_mx_funcs()

# This should be correct! Compare commented out method above
function mk_mx_to_py_funcs()
    for (sjsym,pysym) in SJULIA_TO_SYMPY_FUNCTIONS
        pystr = string(pysym)
        sjstr = string(sjsym)
        obj = eval(parse("sympy." * pystr))
        @eval begin
            mx_to_py_dict[symbol($sjstr)] = $obj
        end
    end
end

mk_mx_to_py_funcs()


function mxpr2sympy(z::Complex)
    if real(z) == 0
        res = mxpr(:Times, :I, imag(z))
    else
        res = mxpr(:Plus, real(z), mxpr(:Times, :I, imag(z)))
    end
    return mxpr2sympy(res)
end

function mxpr2sympy(mx::SJulia.Mxpr{:List})
    return [map(mxpr2sympy, mx.args)...]
end


# mxpr2sympy(mx::SJulia.Mxpr{:Order}) = sympy.Order(map(mxpr2sympy, mx.args)...)

function mxpr2sympy(mx::SJulia.Mxpr)
    if mx.head in keys(mx_to_py_dict)
        return mx_to_py_dict[mx.head](map(mxpr2sympy, mx.args)...)
    end
    pyfunc = sympy.Function(string(mx.head))  # Don't recognize the head, so make it a user function
    return pyfunc(map(mxpr2sympy, mx.args)...)
end

function mxpr2sympy(mx::Symbol)
    if haskey(mx_to_py_dict,mx)
        return mx_to_py_dict[mx]
    end
    return sympy.Symbol(mx)
end

function mxpr2sympy(mx::SJulia.SSJSym)
    name = symname(mx)
    if haskey(mx_to_py_dict,name)
        return conv_rev[name]
    end
    return sympy.Symbol(name)
end

function mxpr2sympy(mx::Number)
    return mx
end

# Don't error, but only warn. Then return x so that we
# can capture and inspect it.
function mxpr2sympy(x)
    warn("Can't convert $x from SJulia to SymPy")
    return x
end


# TESTS

function test_sympy2mxpr()
    x, y, z = sympy.symbols("x y z")
    add1 = sympy.Add(x, y, z, 3)
    @assert sympy2mxpr(add1) == mxpr(:Plus, 3, :x, :y, :z)
    mul1 = sympy.Mul(x, y, z, -2)
    @assert sympy2mxpr(mul1) == mxpr(:Times, -2, :x, :y, :z)
    add2 = sympy.Add(x, mul1)
    @assert sympy2mxpr(add2) == mxpr(:Plus, :x, mxpr(:Times, -2, :x, :y, :z))
end

function test_mxpr2sympy()
    me1 = mxpr(:Plus, :a, :b,  mxpr(:Times, -3, :z, mxpr(:Power, :x, 2)))
    me2 = mxpr(:Times, 2, :x, :y)
    @assert sympy2mxpr(mxpr2sympy(me1)) == me1
    @assert sympy2mxpr(mxpr2sympy(me2)) == me2
end

end  # module SJulia.JSymPy
