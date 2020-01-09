using StatsBase

function argmax_(l, f::Function)
    max_ = ("", 0.0)
    for val in l
        if (res = f(val)) >= max_[2]
            max_ = (val, res)
        end
    end
    max_[1]
end

words(text) = [m.match for m in eachmatch(r"\w+", lowercase(text))]

const WORDS = countmap(words(read(open("./big.txt"), String)))
const KNOWN = Set(keys(WORDS))
const sumwords =  sum(values(WORDS))

known(word) = word in KNOWN

P(word; N=sumwords) = get(WORDS, word, 0.0) / N

function pairs(text)
    d = Dict{Tuple{String, String}, String}()
    for word in text
        for i in 1:length(word)
            L = word[1:(i-1)]
            R = word[(i+1):end]
            (P(get(d, (L, R), "")) < P(word)) && (d[(L, R)] = word)
		end
    end
    d
end
const PAIRS = pairs(keys(WORDS))

correction(word) = argmax_(candidates(word), P)

function candidates(word)
    known(word) && return (word,)

    r = edits1(word)
    length(r)>0 && return r

    r = edits2(word)
    length(r)>0 && return r

    (word,)
end

function edits1(word)
    edits1a!(Set(String[]), word)
end

function edits1a!(edits, word)
    push_word(w) = known(w) && push!(edits, w)
    for i in 0:length(word)
        L = word[1:i]
        R = word[i+1:end]
        if R != ""
            push_word(L * R[2:end])
            ((L, R[2:end]) in keys(PAIRS)) && (push!(edits, PAIRS[(L, R[2:end])])) 
        end

        length(R) > 1 && push_word(L * R[2] * R[1] * R[3:end])

        ((L, R) in keys(PAIRS)) && (push!(edits, PAIRS[(L, R)]))
    end
    edits
end

function edits1b!(edits, word)
    push_word(w) = push!(edits, w)
    letters = 'a':'z'
    for i in 0:length(word)
        L = word[1:i]
        R = word[i+1:end]
        if R != ""
            push_word(L * R[2:end])
            for c in letters
                push_word(L * c * R[2:end])
            end
        end

        length(R) > 1 && push_word(L * R[2] * R[1] * R[3:end])

        for c in 'a':'z'
            push_word(L * c * R)
        end
    end
    edits
end

function edits2(word)
    ed1 = Set(String[])
    edits1b!(ed1, word)
    edits = Set(String[])

    for e1 in ed1
        edits1a!(edits, e1)
    end
    edits
end

function most_common(n::Integer)
     collect(zip(sort(WORDS, by=x->WORDS[x], rev=true)))[1:n]
end

function unit_tests()
    @assert correction("speling") == "spelling"              # insert
    @assert correction("korrectud") == "corrected"           # replace 2
    @assert correction("bycycle") == "bicycle"               # replace
    @assert correction("inconvient") == "inconvenient"       # insert 2
    @assert correction("arrainged") == "arranged"            # delete
    @assert correction("peotry") =="poetry"                  # transpose
    @assert correction("peotryy") =="poetry"                 # transpose + delete
    @assert correction("word") == "word"                     # known
    @assert correction("quintessential") == "quintessential" # unknown
    @assert words("This is a TEST.") == ["this", "is", "a", "test"]
    @assert countmap(words("This is a test. 123; A TEST this is.")) == (
           Dict("123" => 1, "a" => 2, "is" => 2, "test" => 2, "this" => 2))
    @assert length(WORDS) == 32198
    @assert sum(values(WORDS)) == 1115585
    # @assert most_common(10) == [
    #  ("the", 79809),
    #  ("of", 40024),
    #  ("and", 38312),
    #  ("to", 28765),
    #  ("in", 22023),
    #  ("a", 21124),
    #  ("that", 12512),
    #  ("he", 12401),
    #  ("was", 11410),
    #  ("it", 10681)]
    # @assert WORDS["the"] == 79808
    @assert P("quintessential") == 0.0
    @assert 0.07 < P("the") < 0.08
    return "unit_tests pass"
end

function spelltest(tests; verbose=false)
    start = time()
    good, unknown = 0, 0
    n = 0
    for (right, wrong) in tests
        n += 1
        w = correction(wrong)
        good += (w == right)
        if w != right
            unknown += !(right in keys(WORDS))
            if verbose
                println("correction($wrong) => $(w) ($(WORDS[w])); expected $(right) ($(WORDS[right]))")
            end
        end
    end
    dt = time() - start
    println("$(round((good / n), digits=3)) of $(n) correct ($(round((unknown / n), digits=3)) unknown) at $(round((n / dt), digits=3)) words per second")
end

function testset(lines)
    return [(right, wrong)
            for (right, wrongs) in [split(line, ":") for line in lines]
            for wrong in split(wrongs)]
end

println("Running spell-testset1.txt")
@time spelltest(testset(readlines(open("spell-testset1.txt"))))
println("Running spell-testset2.txt")
@time spelltest(testset(readlines(open("spell-testset2.txt"))))
println("Running spell-testset1.txt")
@time spelltest(testset(readlines(open("spell-testset1.txt"))))
println("Running spell-testset2.txt")
@time spelltest(testset(readlines(open("spell-testset2.txt"))))
