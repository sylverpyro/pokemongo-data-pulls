# Pull the JSON file donw manualy from https://pogoapi.net//api/v1/pokemon_max_cp.json

# https://pogoapi.net//api/v1/pokemon_max_cp.json
# form, max_cp, pokemon_id, pokemon_name
$cp_file = "~/Downloads/pokemon_max_cp.json"
$maxcp_data = (Get-Content -Raw $cp_file) | ConvertFrom-Json

# https://pogoapi.net/api/v1/mega_pokemon.json
# first_time_mega_energy_required, form, mega_engery_required, mega_name, pokemon_id, 
# pokemon_name, stats{base_attack, base_defense, base_stamina}, type{VALUE, VALUE}
$mega_file = "~/Downloads/mega_pokemon.json"
$megaforms_data = (Get-Content -Raw $mega_file) | ConvertFrom-Json

# https://pogoapi.net/api/v1/pokemon_stats.json
# base_ttack, base_defense, base_stamina, form, pokemon_id, pokemon_name
$stats_file = "~/Downloads/pokemon_stats.json"
$stats_data = (Get-Content -Raw $stats_file) | ConvertFrom-Json

# https://pogoapi.net/api/v1/pokemon_evolutions.json
# evolutions form,pokemon_id,pokemon_name{HASH_entry{candy_required,form,pokemon_id,pokemon_name}}
$evo_file = "~/Downloads/pokemon_evolutions.json"
$evo_data = (Get-Content -Raw $evo_file) | ConvertFrom-Json

# Type data: https://pogoapi.net/api/v1/pokemon_types.json

# Example of extracting the pokemon id for ivysaur
#Write-Output "Data for mon id 2: base form :: evo from form"
#$evo_data | Where-Object { $_.evolutions.pokemon_id -eq 2 -and $_.evolutions.form -eq "Normal" }
#Write-Output "mon id 2 evovles from: "
#($evo_data | Where-Object { $_.evolutions.pokemon_id -eq 2 }).pokemon_id
#($evo_data | Where-Object { $_.evolutions.pokemon_id -eq 2 }).pokemon_name
#Write-Output "Data for mon id 2: what it evolves to:"
#$evoto_data = ($evo_data | Where-Object { $_.pokemon_id -eq 2 })
#$evoto_data
#exit

# NOTE Evolutions are easier to get from the PokeAPI site due to limitations of PS 5.1
# This does rquire some recursion to get the correct evo chain from the API but it's far
# more accurate and esier than parsing the pogoapi.net evolutions withtout the better
# version of ConvertFrom-Json -AsHashTable
#$api="https://pokeapi.co/api/v2/"
#$api_species="$api/pokemon-species"

## Where-object examples
# Get a mega form by ID number
#$megaforms | Where-Object pokemon_id -EQ $id
# Get the mega form stats by ID number
#($megaforms | Where-Object pokemon_id -EQ $id).stats
# Get just meta form attack by ID number
#($megaforms | Where-Object pokemon_id -EQ $id).stats.base_attack

# Example to just dump the entire thing to a CSV file
#$json | ConvertTo-Csv

# Data that we need
# id:           Nat Pokedex ID
# name:         Name of the Pokemon as far as PoGo is concerned
# from:         The species form of the mon that comes with special/different traits
# is_mega:         Is this mon a 'mega' mon
# atk:          Base attack
# def:          Base Defense
# hp:           Base HP
# max_cp:       Maximum CP of the pokemon's form
# evo_from:     Name of the mon this mon evolves from (blank if none)
# evo_from_id:  ID number of the mon this mon evolves from (blank if none)
# can_evo:   If the mon can evolve at all
# stage:        What evo stage the mon is (1 2 or 3)

Write-Output "id,name,form,readable-name,is_mega,atk,def,hp,max_cp,evo_from,evo_from_id,evo_from_from,evo_from_from_id,can_evo,stage,baby_tiny_league,special_great_league,ultra_league,raid_master_league,collect_only"

# Critical Calculated values
# Collection:   Mon is not suitable for combat at all :: max_cp < 500
# BL:           Mon is suitable for baby league :: max_cp > 500 && can_evo == true
# TL:           Mon is suitable for the tiny league :: max_cp > 500
# SGL:          Mon is suitable for the Special or Great League(s) :: max_cp > 1500
# UL:           Mon is suitable for the Ultra League :: max_cp > 2500
# RML:          Mon is suitable for Raiding or the Master League :: max_cp > 3000

# Not critical to have, but would be fun to have
# shadow_avail: Is this mon has a shadow form available
# shiny_avail:  If the mon has a shiny varriant available
# type_1:       The primary type of the mon
# type_2:       The secondary type of the mon
# family:       The species family/evo lineage of the mon
#  - This isn't available in the pogo api sources unfortunately

# Not critical to have, but would be fun to have
# Generate a link to pokemon.gg for the mon form and ID number

# Would be nice to have, but is multi-valued... so hard to leverage well
# as mons have branching evolution paths
# evo_to:       Name(s) of the mon(s) this mon can evo to
# evo_to_id:    ID(s) of the mon(s) this mon can evo to

# The Max CP table has every pokemon ID in it so we want to itterate through that
#foreach ($record in $maxcp) {
# For testing, using a list of problem mons that need to pass
#$id=@(3, 4, 150, 133, 134, 135, 25, 26, 172)
#$id=@(1, 2, 3, 133, 151)
#$id=@(1, 2, 3)
# NOTE that pogoapi only goes up to 1008 as of Sep 13, 2024
$id=@(1..1017)

# Baby and Tiny league CP cap
$btl_max_cp = 500
# CP cap for Special and Great Leagues
$sgl_max_cp = 1500
# CP Cap for Ultra league
$ul_max_cp = 2500
# Min CP to consider something for Raid and Master League
$rml_min_cp = 3000


foreach ( $record in ( $maxcp_data | Where-Object -property pokemon_id -in -value $id ) ) {
    # Init the default values from the max cp table
    $name = $record.pokemon_name
    $id = $record.pokemon_id
    $form = $record.form
    # Mega is false unless we find a mega evo in the mega check later
    $can_mega = "false"
    # These are all  from the stat data
    $atk = ($stats_data | Where-Object {$_.pokemon_id -eq $id -and $_.form -eq $form}).base_attack
    $def = ($stats_data | Where-Object {$_.pokemon_id -eq $id -and $_.form -eq $form}).base_defense
    $hp = ($stats_data | Where-Object {$_.pokemon_id -eq $id -and $_.form -eq $form}).base_stamina
    $maxcp = $record.max_cp
    $can_evo = ""
    $evo_from = ""
    $evo_from_id = ""
    $evo_from_from = ""
    $evo_from_from_id = ""
    $btl_usable = "false"
    $sgl_usable = "false"
    $ul_usable = "false"
    $rml_usable = "false"
    $collect_only = "false"

    #$collectable_forms = @( "Costume_*", "2020", "Fall_2019" , "Copy_*")
    $is_collectable_form = "false"

    # This is an inclusive filter of all 'collectable' and 'costume' forms
    # released so far
    # This is actually VASTLY smaller than the number of non-normal but also
    # non-costume forms as Gen 8 and Gen 9 started intoducing muliple forms
    # of the same mon ID
    switch -Wildcard ($form) {
        # This covers like 99% of all the custom forms released so far
        "*_*" { $is_collectable_form = "true" }
        "Doctor" { $is_collectable_form = "true" }
        "Adventure_*" { $is_collectable_form = "true" }
        "Horizons" { $is_collectable_form = "true" }
        "Jeju" { $is_collectable_form = "true" }
        "Kariyushi" { $is_collectable_form = "true" }
        #"" { $is_collectable_form = "true" }
    }

    # Pretty much every year has a custom form availab for it, so drop ALL of those
    # NOTE we want to actually be careful here as some mons like Spinda have numbered
    # forms
    if ( $form -match "\d\d\d\d" ) {
        $is_collectable_form = "true"
    }

    # Evolutions are complex
    # See if the mon can evolve from something
    $mon_evo_from_data = ( $evo_data | Where-Object { $_.evolutions.pokemon_id -eq $id -and $_.evolutions.form -eq $form } )
    if ( -not [string]::IsNullOrWhiteSpace($mon_evo_from_data) ) {
        # If it evolves from something save the ID and name
        # Thankfully right now Mons only have single direct precursor evolutions
        $evo_from = $mon_evo_from_data.pokemon_name
        $evo_from_id = $mon_evo_from_data.pokemon_id
    } else {
        # If the do not evo from anything, then just mark these values as empty
        $evo_from = ""
        $evo_from_id = ""
    }

    # Now see if the mon can evolve to anything
    $mon_evo_to_data = ( $evo_data | Where-Object { $_.pokemon_id -eq $id -and $_.form -eq $form } )
    if ( -not [string]::IsNullOrWhiteSpace($mon_evo_to_data) ) {
        # If it can evolve into something mark that as true
        # We don't store WHAT it can evo into as that's not a 1:1 relationship
        # and for purposes of making filters, we don't really care
        $can_evo = "true"
    } else {
        # If it can't evo into anything, then mark that as false
        $can_evo = "false"
    }

    # Figure out wat evo stage this mon is
    # This is tricky as there's actaully 4 cases here
    # A mon with NO evoltuions down - always stage 1
    # A mon with an evo up AND down - always stage 2
    # A mon with an evo down but not up - variable
    ## If the down evo has a further down evo - stage 3
    ## If the down evo does NOT have a further down evo - stage 2
    if ( $evo_from -eq "" ) {
        $stage = 1
        #Write-Output "Stage $stage - Evo from is blank: $evo_from"
    } elseif ( -Not $evo_from -eq "" -And $can_evo -eq "true" ) {
        #Write-Output "Stage $stage - Evo from is blank: $evo_from && can evo is ture: $can_evo"
        $stage = 2
    } else {
        # If we are here we need to derive if the form this mon
        # evolved from ALSO evovled from something else
        $mon_evo_from_evo_from_data = ( $evo_data | Where-Object { $_.evolutions.pokemon_id -eq $evo_from_id -and $_.evolutions.form -eq $form } )
        if ( -not [string]::IsNullOrWhiteSpace($mon_evo_from_evo_from_data) ) {
            # If there are two precursor evolutions to this form it's a stage 3 mon
            $stage = 3
            $evo_from_from = $mon_evo_from_evo_from_data.pokemon_name
            $evo_from_from_id = $mon_evo_from_evo_from_data.pokemon_id
            #Write-Output "Stage $stage - precursor evo $evo_from evolves from $mon_evo_from_evo_from_data"
        } else {
            # If there is one precursor evoltuion, this is a stage 2 mon with only 2 stages
            $stage = 2
            #Write-Output "Stage $stage - precursor evo $evo_from has no other precursor evolutions"
        }
    }



    # See if this mon has a mega form
    $mega_result = ($megaforms_data | Where-Object { $_.pokemon_id -eq $record.pokemon_id -and $_.form -eq $record.form} )
    if ( -not [string]::IsNullOrWhiteSpace( $mega_result ) ) {
        # If it does, we actually need to produce an EXTRA entry for this mon
        # It uses most of the default values but prints different values for
        # name, is_mega, atk, def, hp
        #Write-Output "$($id),$($form),$($mega_result.mega_name),$name-$form-mega,true,$($mega_result.stats.base_attack),$($mega_result.stats.base_defense),$($mega_result.stats.base_stamina),$maxcp,$evo_from,$evo_from_id,$evo_from_from,$evo_from_from_id,$can_evo,$stage,$btl_usable,$sgl_usable,$ul_usable,$rml_usable,$collect_only" 
        $can_mega = "true"
    }

    # Now figure out what PVP leagues (if any) the mon is suited for
    # If it's stage 1 AND can evolove, and it can at least hit the max cp for
    # the tiny/Baby league(s)
    if ( $stage -eq 1 -And $can_evo -eq "true" -And $maxcp -gt $btl_max_cp ) {
        $btl_usable = "true"
    }
    # If it's NOT stage 1 but can still hit at least the max cp for the league, count it too
    if ( $maxcp -gt $btl_max_cp ) {
        $btl_usable = "true"
    }
    if ( $maxcp -gt $sgl_max_cp ) {
        $sgl_usable = "true"
    }
    if ( $maxcp -gt $ul_max_cp ) {
        $ul_usable = "true"
    }
    if ( $maxcp -gt $rml_min_cp -Or $can_mega -eq "true" ) {
        $rml_usable = "true"
    }
    if ( $btl_usable -eq "false" -And $sgl_usable -eq "false" -And $ul_usable -eq "false" -And $rml_usable -eq "false" ) {
        $collect_only = "true"
    }

    if ( $is_collectable_form -eq "false" ) {
        Write-Output "$id,$name,$form,$name-$form,$can_mega,$atk,$def,$hp,$maxcp,$evo_from,$evo_from_id,$evo_from_from,$evo_from_from_id,$can_evo,$stage,$btl_usable,$sgl_usable,$ul_usable,$rml_usable,$collect_only" 
    }
}
#Write-Output "$($json.pokemon_id)"