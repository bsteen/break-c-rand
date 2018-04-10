︠df3ceb3c-bff7-4923-96d0-1c5682a8ce5f︠
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
def pseudo_rand(terms, n):
    results = []
    for i in range(0, 31):
        results.append(terms[i][0])

    for i in range(31, n + 31):
        results.append((results[i-31]+results[i-3]) % 2**32)

    output = []
    for i in range(31, n + 31):
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
def breaker(theinput, theoutput, amount_to_guess):
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
            shifted = theoutput[extra_values] << 1
            simplified += [[shifted, shifted + 1]]
            extra_values += 1
        else:
            print "FOUND SOLUTION with", len(theinput) + extra_values, "consequative numbers from crand (%d was the goal; %d extra values were needed)." % (len(theinput), extra_values)
            return pseudo_rand(simplified[62:], amount_to_guess)

    print "COULD NOT FIND SOLUTION even with 30 extra numbers..."
    return []

# MAIN CODE
theseed = 776412188#randint(1, 2**30)
skip = 37074#randint(10000, 200000)

print "Seed:", theseed
print "Skip:", skip

my_generator = crand(theseed)
for i in range(skip):
    temp = my_generator.next()

# N only tested at 93
n = 93

# First n number to analyze
the_input = [my_generator.next() for i in range(n)]
# Next n numbers to guess
the_output = [my_generator.next() for i in range(n)]

next_numbers = breaker(the_input, the_output, n)

print "Calc'd output:\n", next_numbers
print "Actual crand output:\n", the_output, "\n"

if next_numbers == the_output:
    print "***YOU WIN!***"
else:
    print "TRY AGAIN"
︡77d39cc5-0ca6-47b6-818c-57b09aacb26e︡{"stdout":"Seed: 776412188\n"}︡{"stdout":"Skip: 37074\n"}︡{"stdout":"2"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274, 925841275], [3163362106], [3566317248], [987075490, 987075491], [3776242644], [1565494458], [1532937098, 1532937099], [4082958134], [4160004278], [3639303092, 3639303093], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860, 3439529861], [2232758684], [3497533092], [2808741120, 2808741121], [3109575991], [2725751113], [3734582394, 3734582395], [1977970801], [1997101065], [426690588, 426690589], [1459246149], [3562595523], [1959627686, 1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400, 1625977401], [4203079839], [1826604609], [139751224, 139751225], [3017688534], [257388426], [3874333618, 3874333619], [700692039], [2254489491], [6056910, 6056911], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094, 2917016095], [2767321279], [1071723625], None, [1490042517]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n4"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274, 925841275], [3163362106], [3566317248], [987075490, 987075491], [3776242644], [1565494458], [1532937098, 1532937099], [4082958134], [4160004278], [3639303092, 3639303093], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860, 3439529861], [2232758684], [3497533092], [2808741120, 2808741121], [3109575991], [2725751113], [3734582394, 3734582395], [1977970801], [1997101065], [426690588, 426690589], [1459246149], [3562595523], [1959627686, 1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400, 1625977401], [4203079839], [1826604609], [139751224, 139751225], [3017688534], [257388426], [3874333618, 3874333619], [700692039], [2254489491], [6056910, 6056911], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094, 2917016095], [2767321279], [1071723625], None, [1490042517], [1329112051]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n5"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274, 925841275], [3163362106], [3566317248], [987075490, 987075491], [3776242644], [1565494458], [1532937098, 1532937099], [4082958134], [4160004278], [3639303092, 3639303093], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860, 3439529861], [2232758684], [3497533092], [2808741120, 2808741121], [3109575991], [2725751113], [3734582394, 3734582395], [1977970801], [1997101065], [426690588, 426690589], [1459246149], [3562595523], [1959627686, 1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400, 1625977401], [4203079839], [1826604609], [139751224, 139751225], [3017688534], [257388426], [3874333618, 3874333619], [700692039], [2254489491], [6056910, 6056911], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094, 2917016095], [2767321279], [1071723625], None, [1490042517], [1329112051], [2636133640, 2636133641]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n7"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274, 925841275], [3163362106], [3566317248], [987075490, 987075491], [3776242644], [1565494458], [1532937098, 1532937099], [4082958134], [4160004278], [3639303092, 3639303093], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860, 3439529861], [2232758684], [3497533092], [2808741120, 2808741121], [3109575991], [2725751113], [3734582394, 3734582395], [1977970801], [1997101065], [426690588, 426690589], [1459246149], [3562595523], [1959627686, 1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400, 1625977401], [4203079839], [1826604609], [139751224, 139751225], [3017688534], [257388426], [3874333618, 3874333619], [700692039], [2254489491], [6056910, 6056911], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094, 2917016095], [2767321279], [1071723625], None, [1490042517], [1329112051], [2636133640, 2636133641], [2190734556]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n9"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274, 925841275], [3163362106], [3566317248], [987075490, 987075491], [3776242644], [1565494458], [1532937098, 1532937099], [4082958134], [4160004278], [3639303092, 3639303093], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860, 3439529861], [2232758684], [3497533092], [2808741120, 2808741121], [3109575991], [2725751113], [3734582394, 3734582395], [1977970801], [1997101065], [426690588, 426690589], [1459246149], [3562595523], [1959627686, 1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400, 1625977401], [4203079839], [1826604609], [139751224, 139751225], [3017688534], [257388426], [3874333618, 3874333619], [700692039], [2254489491], [6056910, 6056911], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094, 2917016095], [2767321279], [1071723625], None, [1490042517], [1329112051], [2636133640, 2636133641], [2190734556], [3583601542]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n10"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274, 925841275], [3163362106], [3566317248], [987075490, 987075491], [3776242644], [1565494458], [1532937098, 1532937099], [4082958134], [4160004278], [3639303092, 3639303093], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860, 3439529861], [2232758684], [3497533092], [2808741120, 2808741121], [3109575991], [2725751113], [3734582394, 3734582395], [1977970801], [1997101065], [426690588, 426690589], [1459246149], [3562595523], [1959627686, 1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400, 1625977401], [4203079839], [1826604609], [139751224, 139751225], [3017688534], [257388426], [3874333618, 3874333619], [700692039], [2254489491], [6056910, 6056911], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094, 2917016095], [2767321279], [1071723625], None, [1490042517], [1329112051], [2636133640, 2636133641], [2190734556], [3583601542], [2642190550, 2642190551]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n12"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274, 925841275], [3163362106], [3566317248], [987075490, 987075491], [3776242644], [1565494458], [1532937098, 1532937099], [4082958134], [4160004278], [3639303092, 3639303093], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860, 3439529861], [2232758684], [3497533092], [2808741120, 2808741121], [3109575991], [2725751113], [3734582394, 3734582395], [1977970801], [1997101065], [426690588, 426690589], [1459246149], [3562595523], [1959627686, 1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400, 1625977401], [4203079839], [1826604609], [139751224, 139751225], [3017688534], [257388426], [3874333618, 3874333619], [700692039], [2254489491], [6056910, 6056911], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094, 2917016095], [2767321279], [1071723625], None, [1490042517], [1329112051], [2636133640, 2636133641], [2190734556], [3583601542], [2642190550, 2642190551], [55705448]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n14"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274, 925841275], [3163362106], [3566317248], [987075490, 987075491], [3776242644], [1565494458], [1532937098, 1532937099], [4082958134], [4160004278], [3639303092, 3639303093], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860, 3439529861], [2232758684], [3497533092], [2808741120, 2808741121], [3109575991], [2725751113], [3734582394, 3734582395], [1977970801], [1997101065], [426690588, 426690589], [1459246149], [3562595523], [1959627686, 1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400, 1625977401], [4203079839], [1826604609], [139751224, 139751225], [3017688534], [257388426], [3874333618, 3874333619], [700692039], [2254489491], [6056910, 6056911], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094, 2917016095], [2767321279], [1071723625], None, [1490042517], [1329112051], [2636133640, 2636133641], [2190734556], [3583601542], [2642190550, 2642190551], [55705448], [810751964]] \n\nCOULD NOT FIND SOLUTION. Need another number from c rand to continue.\n17"}︡{"stdout":" total simplifcations needed to verify reduction of combinations.\nSimplified values:\n[[3523185317], [925841274], [3163362106], [3566317248], [987075490], [3776242644], [1565494458], [1532937099], [4082958134], [4160004278], [3639303092], [814431134], [1996158074], [3832551357], [3281736084], [1252567825], [2023352091], [4007314573], [3178760285], [3313240279], [3655677169], [2783456661], [3058508892], [2359920777], [2216647693], [1977324599], [3439529860], [2232758684], [3497533092], [2808741120], [3109575991], [2725751113], [3734582394], [1977970801], [1997101065], [426690588], [1459246149], [3562595523], [1959627687], [1247236987], [3427632505], [1303963483], [2061668121], [1128823283], [841547544], [1048436909], [2381391108], [2864899635], [760784186], [1265184097], [1883172618], [121494059], [4048640758], [646714214], [2481414836], [1970321155], [2624038813], [1625977400], [4203079839], [1826604609], [139751224], [3017688534], [257388426], [3874333618], [700692039], [2254489491], [6056910], [2159938188], [1522117718], [1965684597], [3407175175], [654782927], [3269648080], [1173876000], [1783606210], [4111195624], [2222312909], [4164997318], [2681127963], [2983097095], [1135214119], [269333285], [3104591154], [888887581], [916047499], [1291038694], [2859208736], [3540086312], [2917016094], [2767321279], [1071723625], [3056767318], [1490042517], [1329112051], [2636133640], [2190734556], [3583601542], [2642190550], [55705448], [810751964], [312907851]] \n\nFOUND SOLUTION with 101 consequative numbers from crand (93 was the goal; 8 extra values were needed).\n"}︡{"stdout":"Calc'd output:\n[664556025, 1318066820, 1095367278, 1791800771, 1321095275, 27852724, 405375982, 156453925, 1731440311, 732767445, 1791277965, 170894663, 1624570550, 1699392129, 1282051118, 1559585561, 892472463, 626116017, 2127192621, 1027139105, 30927946, 424152763, 1485162855, 676447293, 1853757131, 1107722363, 2134955340, 1089934123, 1643584175, 1515855351, 1834955381, 160656553, 686438523, 782839011, 1952457324, 2007533798, 810691735, 210349658, 16504076, 394648399, 943117103, 1807782041, 565543062, 420204006, 1359690523, 1847594180, 1979789567, 104679338, 326226550, 1959498540, 1131818443, 357154496, 236167656, 469497650, 1033601790, 2089924787, 1577220013, 1021073482, 1032375262, 1073320541, 389445186, 719846996, 1233977094, 1075883709, 1502686007, 1038950770, 935933860, 165894095, 1249300428, 952437936, 560542494, 44933883, 612736329, 1126085556, 465137889, 1972426852, 826196089, 297443809, 2077106190, 1152422639, 109458701, 1061440986, 1509577135, 345626357, 1530938636, 395695277, 288067497, 960675002, 1416768760, 1320442759, 2033995543, 1806213946, 2040289755]\n"}︡{"stdout":"Actual crand output:\n[664556025, 1318066820, 1095367278, 1791800771, 1321095275, 27852724, 405375982, 156453925, 1731440311, 732767445, 1791277965, 170894663, 1624570550, 1699392129, 1282051118, 1559585561, 892472463, 626116017, 2127192621, 1027139105, 30927946, 424152763, 1485162855, 676447293, 1853757131, 1107722363, 2134955340, 1089934123, 1643584175, 1515855351, 1834955381, 160656553, 686438523, 782839011, 1952457324, 2007533798, 810691735, 210349658, 16504076, 394648399, 943117103, 1807782041, 565543062, 420204006, 1359690523, 1847594180, 1979789567, 104679338, 326226550, 1959498540, 1131818443, 357154496, 236167656, 469497650, 1033601790, 2089924787, 1577220013, 1021073482, 1032375262, 1073320541, 389445186, 719846996, 1233977094, 1075883709, 1502686007, 1038950770, 935933860, 165894095, 1249300428, 952437936, 560542494, 44933883, 612736329, 1126085556, 465137889, 1972426852, 826196089, 297443809, 2077106190, 1152422639, 109458701, 1061440986, 1509577135, 345626357, 1530938636, 395695277, 288067497, 960675002, 1416768760, 1320442759, 2033995543, 1806213946, 2040289755] \n\n"}︡{"stdout":"***YOU WIN!***\n"}︡{"done":true}︡
︠6a841b10-ae18-4337-94ef-c2c5cd3e732as︠
︡0eba0a43-e57a-4f0c-a69f-411c49385418︡{"done":true}︡









