using Optim, Compat
using OptimTestProblems
UP = OptimTestProblems.UnconstrainedProblems
using Base.Test

debug_printing = false

general_tests = [
    "api",
    "callables",
    "callbacks",
    "convergence",
    "deprecate",
    "initial_convergence",
    "objective_types",
    "Optim",
    "optimize",
    "type_stability",
    "types",
    "counter",
]
general_tests = map(s->"./general/"*s*".jl", general_tests)

univariate_tests = [
    # optimize
    "optimize/interface",
    "optimize/optimize",
    # solvers
    "solvers/golden_section",
    "solvers/brent",
    #"initial_convergence",
    "dual",
]
univariate_tests = map(s->"./univariate/"*s*".jl", univariate_tests)

multivariate_tests = [
    # optimize
    "optimize/interface",
    "optimize/optimize",
    # solvers
    ## constrained
    "solvers/constrained/constrained",
    ## first order
    "solvers/first_order/accelerated_gradient_descent",
    "solvers/first_order/bfgs",
    "solvers/first_order/cg",
    "solvers/first_order/gradient_descent",
    "solvers/first_order/l_bfgs",
    "solvers/first_order/momentum_gradient_descent",
    ## second order
    "solvers/second_order/newton",
    "solvers/second_order/newton_trust_region",
    "solvers/second_order/krylov_trust_region",
    ## zeroth order
    "solvers/zeroth_order/grid_search",
    "solvers/zeroth_order/nelder_mead",
    "solvers/zeroth_order/particle_swarm",
    "solvers/zeroth_order/simulated_annealing",
    # other
    "array",
    "extrapolate",
    "lsthrow",
    "precon",
    "manifolds",
    "complex",
]
multivariate_tests = map(s->"./multivariate/"*s*".jl", multivariate_tests)

input_tuple(method, prob) = ((UP.objective(prob),),)
input_tuple(method::Optim.FirstOrderOptimizer, prob) = ((UP.objective(prob),), (UP.objective(prob), UP.gradient(prob)))
input_tuple(method::Optim.SecondOrderOptimizer, prob) = ((UP.objective(prob),), (UP.objective(prob), UP.gradient(prob)), (UP.objective(prob), UP.gradient(prob), UP.hessian(prob)))

function run_optim_tests(method; convergence_exceptions = (),
                         minimizer_exceptions = (),
                         minimum_exceptions = (),
                         f_increase_exceptions = (),
                         iteration_exceptions = (),
                         skip = (),
                         show_name = false,
                         show_trace = false,
                         show_res = false)
    # Loop over unconstrained problems
    for (name, prob) in OptimTestProblems.UnconstrainedProblems.examples
        if !isfinite(prob.minimum) || !any(isfinite, prob.solutions)
            debug_printing && println("$name has no registered minimum/minimizer. Skipping ...")
            continue
        end
        show_name && print_with_color(:green, "Problem: ", name, "\n")
        # Look for name in the first elements of the iteration_exceptions tuples
        iter_id = find(n[1] == name for n in iteration_exceptions)
        # If name wasn't found, use default 1000 iterations, else use provided number
        iters = length(iter_id) == 0 ? 1000 : iteration_exceptions[iter_id[1]][2]
        # Construct options
        options = Optim.Options(allow_f_increases = name in f_increase_exceptions, iterations = iters, show_trace = show_trace)

        # Use finite difference if it is not differentiable enough
        if  !(name in skip)
            for (i, input) in enumerate(input_tuple(method, prob))
                if (!prob.isdifferentiable && i > 1) || (!prob.istwicedifferentiable && i > 2)
                    continue
                end

                # Loop over appropriate input combinations of f, g!, and h!
                results = Optim.optimize(input..., prob.initial_x, method, options)
                @test isa(summary(results), String)
                show_res && println(results)
                if !((name, i) in convergence_exceptions)
                    @test Optim.converged(results)
                end
                if !((name, i) in minimum_exceptions)
                    @test Optim.minimum(results) < prob.minimum + sqrt(eps(typeof(prob.minimum)))
                end
                if !((name, i) in minimizer_exceptions)
                    @test norm(Optim.minimizer(results) - prob.solutions) < 1e-2
                end
            end
        else
            debug_printing && print_with_color(:blue, "Skipping $name\n")
        end
    end
end

@testset "general" begin
    for my_test in general_tests
        println(my_test)
        @time include(my_test)
    end
end
@testset "univariate" begin
    for my_test in univariate_tests
        println(my_test)
        @time include(my_test)
    end
end
@testset "multivariate" begin
    for my_test in multivariate_tests
        println(my_test)
        @time include(my_test)
    end
end
