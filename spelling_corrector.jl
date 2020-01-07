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

known(word) = word in KNOWN

P(word; N=sum(values(WORDS))) = get(WORDS, word, 0.0) / N

correction(word) = argmax_(candidates(word), P)

function candidates(word)
    known(word) && return (word,)

    r = edits1(word, known)
    length(r)>0 && return r

    r = edits2(word)
    length(r)>0 && return r

    (word,)
end



function edits1(word, filter=w->true)
    edits1!(Set(String[]), word, filter)
end

function edits1!(edits, word, filter=w->true)
    splits = Set([("", word)])
    for i in 1:length(word)
        push!(splits, (word[1:i], word[i + 1:end]))
    end

    push_word(w) = filter(w) && push!(edits, w)

    letters = 'a':'z'
    for (L, R) in splits
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
    edits = Set(String[])
    for e1 in edits1(word)
        edits1!(edits, e1, known)
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
