︠350e4ef1-262d-43ed-b0f1-160000b008fds︠
def count_unknowns(lst):
    twos = 0
    nones = 0
    for i in range(len(lst)):
        if list[i] == None:
            nones = nones + 1
        elif len(lst[i]) == 2:
            twos = twos + 1
    print "Nones:", nones
    print "Twos:", twos, "\n"
    return

def print_values(lst):
    for i in range(92, -1, -1):
        print i, lst[i]
        if i - 3 >= 0:
            print i - 3, lst[i - 3]
        if i - 31 >= 0:
            print i - 31, lst[i - 31], "\n"
        else:
            print
︡076609ab-0623-4a14-a5da-ef702829c69f︡{"done":true}︡
︠2ad55cd2-e1bb-4370-b53b-888e614a01fbs︠
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
        # Only if there is ONE set of numbers that sums to the root value
        if len(correct_sums) == 1 and len(correct_selections) == 1:
            for i in range(len(correct_selections[0])):
                idx = indexes[i]
                sel = correct_selections[0][i]
                preshifts[indexes[i]] = [preshifts[idx][sel]]
            # If there are two possible sums for the root index, but only one valid sum was found, we now know the root value
            if len(preshifts[root_index]) == 2:
                print root_index
                preshifts[root_index] = [correct_sums[0]]

    return preshifts

o = [[4082363273], [2431724300], [696752042], [4249415838], [3099128013], [391042619], [1572960905], [4090515894], [594792825], [800340994], [2916570510], [952166835], [15889704], [691115290], [3245787700], [2384135613], [1256210869], [4026808189], [284894467], [1013102802, 1013102803], [29540793], [2842095589], [3554228840, 3554228841], [3269307211], [25509832, 25509833], [3848878138, 3848878139], [3576333175], [1958642982, 1958642983], [2389658123], [1288260298], [3093728991], [2177054100], [3719984598], [3790481033], [2131502642], [2524145315], [4181523652], [3704463547], [2319693913], [481349181], [209837245], [941297127], [1433516016], [225726949], [1632412417], [384336420], [2609862562], [2888623286], [116177313], [2894757029], [3901726088, 3901726089], [145718106], [1441885322], [3160987632, 3160987633], [3415025317], [1467395154, 1467395155], [2714898475], [2696391196], [3426038137], [809589302], [3984651494], [2224799832], [2986643402], [3409668796], [1720313569], [823178748], [1638846815], [1606869925], [232674999], [3958540728], [2088219106], [442512244], [604870559], [3521735122], [668239193], [2237282976], [3906071542], [3278101755], [830938966], [4022248855], [1877891488], [437697758, 437697759], [4167966961], [3319776810], [3598685390, 3598685391], [3288024982], [492204668, 492204669], [2018616568, 2018616569], [1689448882], [3918242804, 3918242805], None, [1379133080], None]
︡70745cc1-86fd-48d8-b614-6878df2a9f60︡{"done":true}︡
︠ea1e3927-b7c8-4520-a905-51132728845a︠










