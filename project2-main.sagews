︠b421d5a3-1e6d-44da-96bb-c61b93a70b63sr︠
# Python implementation of the glibc random number generator rand()
# https://www.mathstat.dal.ca/~selinger/random/
# https://gist.github.com/AndyNovo/94b9974a4945392bc8f4414b6509ca65
def crand(seed):
    r=[]
    r.append(seed)
    for i in range(30):
        r.append((16807*r[-1]) % 2147483647)
        if r[-1] < 0:
            r[-1] += 2147483647
    for i in range(31, 34):
        r.append(r[len(r)-31])
    for i in range(34, 344):
        r.append((r[len(r)-31] + r[len(r)-3]) % 2**32)
    while True:
        next = r[len(r)-31]+r[len(r)-3] % 2**32
        r.append(next)
        yield (next >> 1 if next < 2**32 else (next % 2**32) >> 1)

# Generate next n terms of crand using the known previous 31 terms (known 31 terms must be consecutive)
def pseudo_rand(terms, n, extra):
    results = []
    output = []

    for i in range(0, 31):
        results.append(terms[i][0])

    # If extra values were needed to break the sequence, we need to account for that here by generating further into the sequence
    for i in range(31, extra + n + 31):
        results.append((results[i-31]+results[i-3]) % 2**32)

    # Skip over the extra values since the c rand state has already moved passed them if we requested more numbers
    for i in range(31 + extra, extra + n + 31):
        output.append(results[i] >> 1)
    return output

# Given index (nth value in theinput), calculate the potenial pre-right-shifted values of theinput[n - 31] and theinput[n - 3]
def calculate_pre_shifts(theinput, index):
    n = theinput[index]
    n31_shifted = theinput[index - 31] << 1
    n3_shifted = theinput[index - 3] << 1
    n_sum = (n31_shifted + n3_shifted) % 2**32

    if n_sum >> 1 == n:
        return [[n3_shifted, n3_shifted + 1],[n31_shifted, n31_shifted + 1]]
    else:
        return [[n3_shifted + 1], [n31_shifted + 1]]

# Checks to make sure pre-shifted values actually equal the expected value
# Only verifies values that have a single option for both composite values and a single option for the preshift value
# Used for debugging
def verify_pre_shift_values(theinput, preshifts):
    for i in range(31, len(theinput)):
        if preshifts[i] != None and len(preshifts[i]) == 1:
            i3_good = preshifts[i - 3] != None and len(preshifts[i - 3]) == 1
            i31_good = preshifts[i - 31] != None and len(preshifts[i - 31]) == 1
            if i3_good and i31_good:
                s = (preshifts[i - 3][0] + preshifts[i - 31][0]) % 2**32
                assert s == preshifts[i][0]
                assert preshifts[i][0] >> 1 == theinput[i]
        elif preshifts[i] != None and len(preshifts[i]) == 2:
            assert preshifts[i][0] >> 1 == theinput[i], "preshifts[%d][0] does not downshift to expected value." % i
            assert preshifts[i][1] >> 1 == theinput[i], "preshifts[%d][1] does not downshift to expected value." % i
#     print "All preshifted values with one option seem correct.\n"

# When there is only one option for each composite value, you can confidently calculate the actual pre-shift value
# Takes care of cases: Two preshift values, one option for each composite value; No preshift value, one option for each composite value
def simplify_single_composite_value(preshifts):
    for n in range(31, len(preshifts)):
        if preshifts[n - 3] != None and preshifts[n - 31] != None:
            if len(preshifts[n - 3]) == 1 and len(preshifts[n - 31]) == 1:
                preshifts[n] = [(preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32]
    return preshifts

# When there is only one possible pre-shift value and one of the two composite values are also decided,
# you can deduce the correct value for the other undecided composite value
# This function is HIDEOUS
def simplify_last_double_composite(theinput, preshifts):
    for n in range(31, len(preshifts)):
        # Only one possible pre-shift value
        if preshifts[n] != None and len(preshifts[n]) == 1:
            # N - 3 is decided, but N - 31 isn't
            if preshifts[n - 3] != None and len(preshifts[n - 3]) == 1:
                if (preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32 == preshifts[n][0]:
                    preshifts[n - 31] = [preshifts[n - 31][0]]
                else:
                    preshifts[n - 31] = [preshifts[n - 31][1]]
            # N - 31 is decided, but N - 3 isn't
            elif preshifts[n - 3] != None and len(preshifts[n - 31]) == 1:
                if (preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32 == preshifts[n][0]:
                    preshifts[n - 3] = [preshifts[n - 3][0]]
                else:
                    preshifts[n - 3] = [preshifts[n - 3][1]]
            # Getting here means each composite value still has two options (BAD case...)

        # Check when preshifts[n] is None, but also has a composite value with only one option
        elif preshifts[n] == None and preshifts[n - 3] != None and preshifts[n - 31] != None:
            if len(preshifts[n - 3]) == 1:
                if ((preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32) >> 1 == ((preshifts[n - 3][0] + preshifts[n - 31][1]) % 2**32) >> 1:
                    continue # Even though a composite value has only one option, the downshift means the second composite values still has 2 valid options
                elif ((preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32) >> 1 == theinput[n]:
                    preshifts[n] = [(preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32]
                    preshifts[n - 31] = [preshifts[n - 31][0]]
                elif ((preshifts[n - 3][0] + preshifts[n - 31][1]) % 2**32) >> 1 == theinput[n]:
                    preshifts[n] = [(preshifts[n - 3][0] + preshifts[n - 31][1]) % 2**32]
                    preshifts[n - 31] = [preshifts[n - 31][1]]
                else: # Sanity Check
                    assert False, "preshifts[%d] == None, but a composite value with only option doesn't get the correct result" % n
            elif len(preshifts[n - 31]) == 1:
                if ((preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32) >> 1 == ((preshifts[n - 3][1] + preshifts[n - 31][0]) % 2**32) >> 1:
                    continue # Even though a composite value has only one option, the downshift means the second composite values still has 2 valid options
                elif ((preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32) >> 1 == theinput[n]:
                    preshifts[n] = [(preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32]
                    preshifts[n - 3] = [preshifts[n - 3][0]]
                elif ((preshifts[n - 3][1] + preshifts[n - 31][0]) % 2**32) >> 1 == theinput[n]:
                    preshifts[n] = [(preshifts[n - 3][1] + preshifts[n - 31][0]) % 2**32]
                    preshifts[n - 3] = [preshifts[n - 3][1]]
                # Sanity Check
                else:
                    assert False, "preshifts[%d] == None, but a composite value with only option doesn't get the correct result" % n
            # Getting here means each composite value still has two options and preshifts[n] == None (VERY BAD case...)

        # Getting here means one or both composite values is None and preshifts[n] == None (SUPER BAD case, but not likely...)
    return preshifts

# Used by simplifiy_down_tree
class VariableGenerator(object):
    def __init__(self, prefix):
        self.__prefix = prefix

    @cached_method
    def __getitem__(self, key):
        return SR.var("%s%s"%(self.__prefix,key))

# Used by simplifiy_down_tree
def aa(init, n, preshifts, a, answers):
    if n in answers:
        return answers[n]
    if n <= 30:
        answers[n] = a[n]
        return a[n]
    elif n != init and preshifts[n] != None and len(preshifts[n]) == 1:
        answers[n] = a[n]
        return a[n]
    else:
        answers[n] =  aa(init, n-31, preshifts, a, answers) + aa(init, n-3, preshifts, a, answers)
        return answers[n]

# Given a list of indexes, return the number of those indexes that have two possible preshift values
# Used by simplifiy_down_tree
def count_double_options(lst, preshifts):
    count = 0
    for index in lst:
        if len(preshifts[index]) == 2:
            count += 1
    return count

# If a "root" preshift value has only one option, but multiple composite values, this function goes down the "tree" of dependencies and tries to find a single combination
# that sums the preshift values; if it does, it replaces all the "leaf" composite values with the only possible combination to equal the root
def simplifiy_down_tree(preshifts):
    preshift_len = len(preshifts)
    for root_index in range(31, preshift_len):
        if preshifts[root_index] == None:
            continue

        a = VariableGenerator('a')
        answers = {}
        eq = aa(root_index, root_index, preshifts, a, answers)
        coes = [eq.coefficient(a[i]) for i in range(preshift_len)]
        indexes = [] # Indexes the composotion values for a given preshift value
        coefficients = [] # Coefficients of the composotion values when they are summed up to the main preshift value

        for i in range(preshift_len):
            if coes[i] != 0:
                coefficients.append(coes[i])
                indexes.append(i)

        sums = []       # Sum of the combination of all possible composition values
        selections = [] # A value in this list belongs to the correspoding index in indexes; Keeps track of which of the preshift values for a given index was used when creating the sum
        num_doubles = count_double_options(indexes, preshifts) # Used for trying each combination when generating sums

        for i in range(2**num_doubles):
            s = 0      # Counting varibles sum
            po = []    # Keeps track of potential selections for current iteration
            shift_by = num_doubles - 1
            for j in range(len(indexes)):
                index = indexes[j]
                coe = coefficients[j]
                pick_option = 0
                if len(preshifts[index]) == 2:
                    pick_option = (i >> shift_by) & 1
                    shift_by -= 1
                po.append(pick_option)
                s = int((s + int(coe * preshifts[index][pick_option])) % 2**32)
            sums.append(s)
            selections.append(po)

        correct_sums = []
        correct_selections = []
        for i in range(len(sums)):
            if sums[i] == preshifts[root_index][0] or (len(preshifts[root_index]) == 2 and sums[i] == preshifts[root_index][1]):
                correct_sums.append(sums[i])
                correct_selections.append(selections[i])
        # Only if there is ONE set of numbers that sums to the root value, you now know the only possible composite values
        if len(correct_sums) == 1 and len(correct_selections) == 1:
            for i in range(len(correct_selections[0])):
                idx = indexes[i]
                sel = correct_selections[0][i]
                preshifts[indexes[i]] = [preshifts[idx][sel]]
            # If there are two possible sums for the root index, but only one valid sum was found, we now also know the root value
            if len(preshifts[root_index]) == 2:
                preshifts[root_index] = [correct_sums[0]]

    return preshifts

# After all possible preshift values are initially calculated, try to remove options that are not possible
# Called by breaker after it has calcuate the initial preshift possibilites
def simplify_pre_shifts(theinput, preshifts):
    preshifts = simplify_single_composite_value(preshifts)
    preshifts = simplify_last_double_composite(theinput, preshifts)
    preshifts = simplifiy_down_tree(preshifts)

    # If the program is finding solutions and they doesn't match the actual output, enable this function call to help debug
    # verify_pre_shift_values(theinput, preshifts)

    return preshifts

# When the finding the initial preshifted values, there will be overlaps becasue of the n-3 and n-31 offsets
# This function resolves any conflicts that might occur becasue of this.
# Called by breaker function
def resolve_overlaps(pre_shift_values, result, index):
    # If the overlap result is the same as the result already found, just thow it out
    if pre_shift_values[index] == result:
        return pre_shift_values[index]
    # If the initial result only has one option, you know that it's alreay correct and can throw out the overlap result
    elif len(pre_shift_values[index]) == 1:
        return pre_shift_values[index]
    # If there is only one overlap result and two previus results, you know the single results is the only possible answer
    elif len(result) == 1 and len(pre_shift_values[index]) == 2:
        pre_shift_values[index] = result
        return pre_shift_values[index]
    # Sanity check, just in case...
    else:
        pre_shift_values[index] = pre_shift_values[index] + result
        return pre_shift_values[index]

# Check to see of the last 30 generated numbers only have one possible pre-shift value
# (Need to have value for 93 - 31 = index 62 and foward)
def check_if_complete(simplified_preshifts):
    for i in range(92, 61, -1):
        if simplified_preshifts[i] == None or len(simplified_preshifts[i]) != 1:
            return False
    return True

# My code to break the C RNG and guess the next n numbers
# TO DO: change theoutput to the generator instead; Make sure len(theinput) >= 93
def breaker(theinput, rand_gen, amount_to_guess):
    pre_shift_values = [None] * len(theinput) # Contains the potential pre-right shifted values of the input 93 input values

    # Calculate all possible preshifted values and their composite values
    for i in range(31, len(theinput)):
        results = calculate_pre_shifts(theinput, i)
        if pre_shift_values[i - 3] != None:
            pre_shift_values[i - 3] = resolve_overlaps(pre_shift_values, results[0], i - 3)
        else:
            pre_shift_values[i - 3] = results[0]

        if pre_shift_values[i - 31] != None:
            pre_shift_values[i - 31] = resolve_overlaps(pre_shift_values, results[1], i - 31)
        else:
            pre_shift_values[i - 31] = results[1]

    # Do the first simplfication
    prev_simplified = pre_shift_values[:]
    simplified = simplify_pre_shifts(theinput, pre_shift_values)

    num_simps = 1        # How many iterations of the simplification functions are needed to run before the pre-shift values can't be reduced anymore
    extra_values = 0     # If solution can't be found with the initial set of numbers, need to generate the next c rand value and see if we can solve then

    # If it takes more than 31 extra values to break the sequence, something is very wrong...
    while extra_values < 31 :
        while simplified != prev_simplified:
            prev_simplified = simplified[:]
            simplified = simplify_pre_shifts(theinput, simplified)
            num_simps = num_simps + 1

        print num_simps, "total simplifcations needed to verify reduction of combinations."
        print "Simplified values:\n", simplified, "\n"

        if not check_if_complete(simplified):
            print "COULD NOT FIND SOLUTION. Need another number from c rand to continue."
            shifted = rand_gen.next() << 1     # Generate the next random number in the sequence
            simplified += [[shifted, shifted + 1]]
            extra_values += 1
        else:
            print "FOUND SOLUTION with", len(theinput) + extra_values, "consequative numbers from crand (%d was the goal; %d extra values were needed)." % (len(theinput), extra_values)
            return pseudo_rand(simplified[62:], amount_to_guess, extra_values)

    print "COULD NOT FIND SOLUTION even with 30 extra numbers..."
    return []

# MAIN CODE
theseed = randint(1, 2**30)
skip = randint(10000, 200000)

print "Seed:", theseed
print "Skip:", skip

my_generator = crand(theseed)
for i in range(skip):
    temp = my_generator.next()

# N only tested at 93
N = 93

# First N number to analyze
the_input = [my_generator.next() for i in range(N)]

# Try to predict the next N numbers (may have to generate more values if N is not enough)
next_numbers = breaker(the_input, my_generator, N)

# Actually generate the next numbers following the orignal first N, plus any extras needed by the breaker
the_output = [my_generator.next() for i in range(N)]

print "Calc'd output:\n", next_numbers
print "Actual crand output:\n", the_output, "\n"

if next_numbers == the_output:
    print "***YOU WIN!***"
else:
    print "TRY AGAIN"
︡d862e593-8257-43a8-bb7e-ac41599655c7︡{"stdout":"Seed: 646570124\n"}︡{"stdout":"Skip: 70223\n"}︡{"stdout":"3"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3228888486, 3228888487], [3125479294], [113461770], [962096944, 962096945], [4032451948], [3195852282], [2355945696, 2355945697], [360306272], [2884225999], [4253567918, 4253567919], [3429469843], [3200637762], [1547494274, 1547494275], [3926559047], [283215914], [1029046160, 1029046161], [4066789999], [1693219180], [3353236170, 3353236171], [3758543381], [2330864450], [3810312408, 3810312409], [3048617676, 3048617677], [2383196562], [3444514388, 3444514389], [503749490, 503749491], [1706843117], [2488560760, 2488560761], [3858310304, 3858310305], [525349900], [2759261760], [2792231494, 2792231495], [3650829194], [2872723530], [3754328438, 3754328439], [3388313846], [1773608516], [1815306838, 1815306839], [3748620118], [362867219], [1773907460, 1773907461], [2883122665], [3563504981], [3321401734, 3321401735], [2514714416], [3846720895], [55480598, 55480599], [2286537119], [1244972779], [3408716768, 3408716769], [1750113204], [3575837229], [2924061880, 2924061881], [503763584, 503763585], [1664066495], [2073608972, 2073608973], [1007513074, 1007513075], [3370909612], [267202437], [570856082, 570856083], [3896259512], [3026464197], [3363087576, 3363087577], [3252121410], [1604220431], [2822448718, 2822448719], [2345467960], [3377828947], [342788260, 342788261], [1799120782], [3740696166], [2116695720, 2116695721], [387276151], [3009233851], [1143130158, 1143130159], [2901990567], [2560987450], [1198610756, 1198610757], [893560390], [3805960229], [312360228, 312360229], [2643673594], [3086830162], [3236422108, 3236422109], [3147437178, 3147437179], [455929361], [1015063785], [4154950252, 4154950253], [3826838973], [1282266222], None, [3428131189], [13763123]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n4"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3228888486, 3228888487], [3125479294], [113461770], [962096944, 962096945], [4032451948], [3195852282], [2355945696, 2355945697], [360306272], [2884225999], [4253567918, 4253567919], [3429469843], [3200637762], [1547494274, 1547494275], [3926559047], [283215914], [1029046160, 1029046161], [4066789999], [1693219180], [3353236170, 3353236171], [3758543381], [2330864450], [3810312408, 3810312409], [3048617676, 3048617677], [2383196562], [3444514388, 3444514389], [503749490, 503749491], [1706843117], [2488560760, 2488560761], [3858310304, 3858310305], [525349900], [2759261760], [2792231494, 2792231495], [3650829194], [2872723530], [3754328438, 3754328439], [3388313846], [1773608516], [1815306838, 1815306839], [3748620118], [362867219], [1773907460, 1773907461], [2883122665], [3563504981], [3321401734, 3321401735], [2514714416], [3846720895], [55480598, 55480599], [2286537119], [1244972779], [3408716768, 3408716769], [1750113204], [3575837229], [2924061880, 2924061881], [503763584, 503763585], [1664066495], [2073608972, 2073608973], [1007513074, 1007513075], [3370909612], [267202437], [570856082, 570856083], [3896259512], [3026464197], [3363087576, 3363087577], [3252121410], [1604220431], [2822448718, 2822448719], [2345467960], [3377828947], [342788260, 342788261], [1799120782], [3740696166], [2116695720, 2116695721], [387276151], [3009233851], [1143130158, 1143130159], [2901990567], [2560987450], [1198610756, 1198610757], [893560390], [3805960229], [312360228, 312360229], [2643673594], [3086830162], [3236422108, 3236422109], [3147437178, 3147437179], [455929361], [1015063785], [4154950252, 4154950253], [3826838973], [1282266222], None, [3428131189], [13763123], [3793926614, 3793926615]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n6"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3228888486, 3228888487], [3125479294], [113461770], [962096944, 962096945], [4032451948], [3195852282], [2355945696, 2355945697], [360306272], [2884225999], [4253567918, 4253567919], [3429469843], [3200637762], [1547494274, 1547494275], [3926559047], [283215914], [1029046160, 1029046161], [4066789999], [1693219180], [3353236170, 3353236171], [3758543381], [2330864450], [3810312408, 3810312409], [3048617676, 3048617677], [2383196562], [3444514388, 3444514389], [503749490, 503749491], [1706843117], [2488560760, 2488560761], [3858310304, 3858310305], [525349900], [2759261760], [2792231494, 2792231495], [3650829194], [2872723530], [3754328438, 3754328439], [3388313846], [1773608516], [1815306838, 1815306839], [3748620118], [362867219], [1773907460, 1773907461], [2883122665], [3563504981], [3321401734, 3321401735], [2514714416], [3846720895], [55480598, 55480599], [2286537119], [1244972779], [3408716768, 3408716769], [1750113204], [3575837229], [2924061880, 2924061881], [503763584, 503763585], [1664066495], [2073608972, 2073608973], [1007513074, 1007513075], [3370909612], [267202437], [570856082, 570856083], [3896259512], [3026464197], [3363087576, 3363087577], [3252121410], [1604220431], [2822448718, 2822448719], [2345467960], [3377828947], [342788260, 342788261], [1799120782], [3740696166], [2116695720, 2116695721], [387276151], [3009233851], [1143130158, 1143130159], [2901990567], [2560987450], [1198610756, 1198610757], [893560390], [3805960229], [312360228, 312360229], [2643673594], [3086830162], [3236422108, 3236422109], [3147437178, 3147437179], [455929361], [1015063785], [4154950252, 4154950253], [3826838973], [1282266222], None, [3428131189], [13763123], [3793926614, 3793926615], [2385285303]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n8"}︡
︠9efc0440-224c-4068-8a0f-95451200c926︠









