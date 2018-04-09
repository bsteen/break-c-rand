︠df3ceb3c-bff7-4923-96d0-1c5682a8ce5f︠
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

# Generate next n terms of crand using the previous 31 terms
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
def check_pre_shift_values(theinput, preshifts):
    for i in range(31, 93):
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
    for n in range(31, 93):
        if len(preshifts[n - 3]) == 1 and len(preshifts[n - 31]) == 1:
            preshifts[n] = [(preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32]
    return preshifts

# When there is only one possible pre-shift value and one of the two composite values are also decided,
# you can deduce the correct value for the other undecided composite value
# This function is HIDEOUS
def simplify_last_double_composite(theinput, preshifts):
    for n in range(31, 93):
        # Only one possible pre-shift value
        if preshifts[n] != None and len(preshifts[n]) == 1:
            # N - 3 is decided, but N - 31 isn't
            if len(preshifts[n - 3]) == 1:
                if (preshifts[n - 3][0] + preshifts[n - 31][0]) % 2**32 == preshifts[n][0]:
                    preshifts[n - 31] = [preshifts[n - 31][0]]
                else:
                    preshifts[n - 31] = [preshifts[n - 31][1]]
            # N - 31 is decided, but N - 3 isn't
            elif len(preshifts[n - 31]) == 1:
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
    elif n != init and len(preshifts[n]) == 1:
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
    for root_index in range(31, 93):
        if preshifts[root_index] == None:
            continue

        a = VariableGenerator('a')
        answers = {}
        eq = aa(root_index, root_index, preshifts, a, answers)
        coes = [eq.coefficient(a[i]) for i in range(93)]
        indexes = [] # Indexes the composotion values for a given preshift value
        coefficients = [] # Coefficients of the composotion values when they are summed up to the main preshift value

        for i in range(93):
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

    # Verify single value preshifts with single option compsite values are interally correct
    check_pre_shift_values(theinput, preshifts)

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
# (Need to have one value for 93 - 31 = index 62 and foward)
def check_if_complete(simplified_preshifts):
    for i in range(92, 61, -1):
        if simplified_preshifts[i] == None or len(simplified_preshifts[i]) != 1:
            return False
    return True

# My code to break the C RNG and guess the next n numbers
def breaker(theinput, amount_to_guess):
    pre_shift_values = [None] * 93 # Contains the potential pre-right shifted values of the input 93 input values

    # Calculate all possible preshifted values and their composite values
    for i in range(31, 93):
        results = calculate_pre_shifts(theinput, i)
        if pre_shift_values[i - 3] != None:
            pre_shift_values[i - 3] = resolve_overlaps(pre_shift_values, results[0], i - 3)
        else:
            pre_shift_values[i - 3] = results[0]

        if pre_shift_values[i - 31] != None:
            pre_shift_values[i - 31] = resolve_overlaps(pre_shift_values, results[1], i - 31)
        else:
            pre_shift_values[i - 31] = results[1]

#     print "input:\n", theinput, "\n"
#     print "initial preshifts:\n", pre_shift_values, "\n"

    prev_simplified = pre_shift_values[:]
    simplified = simplify_pre_shifts(theinput, pre_shift_values)
    num_simps = 1

    while simplified != prev_simplified:
        prev_simplified = simplified[:]
        simplified = simplify_pre_shifts(theinput, simplified)
        num_simps = num_simps + 1

    print num_simps, "simplifcations needed to verify reduction of combinations."
    print "Simplified:\n", simplified, "\n"

    # Once the last 31 preshifted values are know, you can calculate every following crand number (e.g. the next 93 required for this project)
    if check_if_complete(simplified):
        print "Found solution!", "\n"
        return pseudo_rand(simplified[62:], amount_to_guess)
    else:
        print "Couldn't find solution", "\n"
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
n = 93

# First n number to analyze
the_input = [my_generator.next() for i in range(n)]
# Next n numbers to guess
the_output = [my_generator.next() for i in range(n)]

next_numbers = breaker(the_input, n)

print "Calc'd output:", next_numbers, "\n"
print "Actual output:\n", the_output, "\n"

if next_numbers == the_output:
    print "You win!"
else:
    print "Try again"
︡4342b07a-851d-4362-8fe9-c768f5b39546︡{"stdout":"Seed: 398348314\n"}︡{"stdout":"Skip: 199055\n"}︡︡{"stdout":"3"}︡{"stdout":" simplifcations needed to verify reduction of combinations.\nSimplified:\n[[2297253726, 2297253727], [767906285], [4224881466], [4028870878, 4028870879], [2006528149], [1692547136], [2969195250, 2969195251], [532525632], [1946922358], [1064007214, 1064007215], [3554141262], [498997637], [345275491], [1136733501], [1059914084], [668632531], [332935395], [2018653380], [1387415432], [1825656294, 1825656295], [1379470949], [1866250950], [2268129750, 2268129751], [2856730057], [2319778386], [1548055108, 1548055109], [3330558361], [1244003363], [3650065588, 3650065589], [3479747712], [2995598078], [1652352018, 1652352019], [4247653997], [2925512248], [1386255600, 1386255601], [1959214850], [323092088], [60483554, 60483555], [2491740482], [2270014446], [1124490769], [1750914448], [2769012083], [1469766260], [2887647949], [3828926167], [2138398791], [3220583344], [1552612251], [3525814223], [751272342, 751272343], [2932083200], [1097097877], [3019402092, 3019402093], [1493845961], [3416876263], [272489904, 272489905], [529437026], [365912330], [3922555492, 3922555493], [4009184738], [3361510408], [1279940214, 1279940215], [3961871439], [1992055360], [2666195814, 2666195815], [1626118993], [2315147448], [2726679369], [4117859475], [290194598], [3851170138], [1573806627], [3059206681], [1025969102], [166487280], [2593165552], [3164367893], [3387070624], [4145777803], [2395214820], [4138342966, 4138342967], [2782893707], [3492312697], [2862777762, 2862777763], [4276739668], [2614221664], [3135267666, 3135267667], [511209398], [2980133994], None, [225426840], [2046677106]] \n\nCouldn't find solution \n\n"}︡{"stdout":"Calc'd output: [] \n\n"}︡{"stdout":"Actual output:\n[2021398038, 2093649139, 2019366233, 1207012297, 759224988, 1029456309, 422868333, 670671077, 1174553608, 200969754, 1457574391, 556673300, 713954305, 1540818031, 1853256076, 148654604, 1086869695, 1778661330, 1346262014, 1008557530, 1022624535, 944934714, 292462763, 1013510721, 104561898, 1860096596, 1269115420, 1594628895, 1094040879, 1381828840, 470483800, 967955269, 1327994332, 342366385, 27483918, 2087219320, 1371822694, 450352251, 610406749, 398892654, 651322006, 2067981140, 955565955, 1365276311, 1461315523, 661338383, 1513930915, 400701570, 292516065, 712709281, 1409259100, 1315140601, 1657643996, 1701721863, 181167674, 1762205894, 1414334811, 1450283095, 1209351142, 360892042, 684628287, 1679834942, 1328847311, 2012622619, 2022201328, 1356331229, 1952358291, 1246540374, 1806683481, 415281393, 1645433029, 310521839, 335778885, 453515336, 1675798150, 1797094409, 1114853719, 1042245418, 50312331, 1407369785, 1754954699, 1459571432, 575026738, 1265115047, 1013809647, 756194412, 879837294, 280660811, 58993859, 2089188436, 641552853, 743622147, 1621539730] \n\n"}︡{"stdout":"Try again\n"}︡{"done":true}
︠61a2fe18-a026-4d18-9e93-9b9eac7aa9dcs︠
︡a72882fd-0a74-49e9-835d-2f16f1e6e07d︡{"done":true}︡









