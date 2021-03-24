module EGraphs

include("../docstrings.jl")

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

import ..Rule
import ..getrhsfun

using ..TermInterface
using ..Util

include("enode.jl")
export ENode

include("abstractanalysis.jl")
export AbstractAnalysis

include("eclass.jl")
export EClass
export hasdata
export getdata
export setdata!

include("egg.jl")
export find
export geteclass
export ariety
export EGraph
export merge!
export addexpr!
export addanalysis!
export rebuild!

include("analysis.jl")
export analyze!

include("ematch.jl")
include("Schedulers/Schedulers.jl")
export Schedulers
using .Schedulers

include("saturation_reason.jl")
export ReportReasons
include("saturation_report.jl")
include("saturation_params.jl")
export SaturationParams
include("saturation.jl")
export saturate!
include("equality.jl")
export areequal
export @areequal
export @areequalg

include("extraction.jl")
export extract!
export ExtractionAnalysis
export astsize
export astsize_inv
export @extract

end
