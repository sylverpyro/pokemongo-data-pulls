# Full scrape is
# $startingid=1
# $endingid=1025

$startingid=1
$endingid=1025

$api="https://pokeapi.co/api/v2/"
$api_species="$api/pokemon-species"

Write-Output "api_id,nat_dex_id,name,can_evolve,evo_stage,evo_stages,evolves_from,generation"

$species = ""
$chainuri = ""
$name = ""
$gen = ""

for ($id=$startingid ; $id -le $endingid ; $id=$id+1) {
    # Pull the JSON for the species ID
    $species = Invoke-WebRequest $api_species/$id | ConvertFrom-json
    # Pull the evo chain from the JSON if it exists
    $chainuri = "$($species.evolution_chain.url)"
    # Pull the species name from the ID JSON
    $name = $species.name
    # And the generation specifier
    $gen = $species.generation.name
    # And the national dex number
    # This should ALWAYS be the first entry in the hash table
    # Future work: Crawl the pokedex entries to get this properly
    if ( $($species.pokedex_numbers.pokedex.name[0]) -eq "national" ) {
        $natdexid = $species.pokedex_numbers.entry_number[0]
    } else {
        $natdexid = $id
    }

    # If there was an evo chain
    if ( -not [string]::IsNullOrWhiteSpace($chainuri) ) {
        # Pull out the evo chian
        $evochain = Invoke-WebRequest $chainuri | ConvertFrom-Json

        # Now figure out where in the evo tree this is
        # If the name is the base name on the chain
        # its the lowest level of mon in the family
        #Write-Output "Raw: $($evochain.chain.evolves_to.species.name)"
        $evo_1 = $evochain.chain.species.name
        #Write-Output "  evo 1 : $($evo_1)"
        $evo_2 = $evochain.chain.evolves_to.species.name
        #Write-Output "  evo 2 : $($evo_2)"
        $evo_3 = $evochain.chain.evolves_to.evolves_to.species.name
        #Write-Output "  evo 3 : $($evo_3)"
        $evo_stage = ""

        # NOTE: Because some mons have mulitple evo forms at each stage and
        #  I can't figure out how to itterate over elements that may or may not
        #  be part of a hash, this is just a brute force attempt
        if ( $name -eq $evo_1 ) {
            $evo_stage = 1
            #Write-Output "evo 1: $($name) = $($evo_1)"
        } elseif ( -not [string]::IsNullOrWhiteSpace($evo_2) -And $evo_stage -eq "" -And ( $name -eq $evo_2 -Or $name -eq $evo_2[0] -Or $name -eq $evo_2[1] ) ) {
            #Write-Output "evo 2: $($name) = $($evo_2)"
            #if ( $name -eq $evo_2 -Or $name -eq $evo_2[0] -Or $name -eq $evo_2[1] ) {
                $evo_stage = 2
            #}
        } elseif ( -not [string]::IsNullOrWhiteSpace($evo_3) -And $evo_stage -eq "" -And ( $name -eq $evo_3 -Or $name -eq $evo_3[0] -Or $name -eq $evo_3[1] ) ) {
            #Write-Output "evo 3: $($name) = $($evo_3)"
            #if ( $name -eq $evo_3 -Or $name -eq $evo_3[0] -Or $name -eq $evo_3[1] ) {
                $evo_stage = 3
            #}
        } else {
            $evo_stage = "error-no-match: $($name) != { $($evo_1) , $($evo_2) , $($evo_3) }"
        }
        #Write-Output "Evo stage: $($evo_stage)"

        # See how many stages this mon has total
        if ( -not [string]::IsNullOrWhiteSpace($evo_3) ) {
            #Write-Output "  3 stage mon: $($evo_3)"
            $evo_stages = 3
        } elseif ( -not [string]::IsNullOrWhiteSpace($evo_2) ) {
            #Write-Output "  2 stage mon: $($evo_2)"
            $evo_stages = 2
        } else {
            #Write-Output "  1 stage mon: $($evo_1)"
            $evo_stages = 1
        }

        if ( $evo_stage -eq $evo_stages ) {
            $canevo = "false"
        } else {
            $canevo = "true"
        }

    } else {
        # If there's no evo chain then this species does not evolve
        # It's family is just it's name
        #Write-Output "No evo chain uri found"
        $canevo = "false"
        $evo_stages = 1
        $evo_stage = 1
    } 
    # Write out CSV
    write-output "$($id),$($natdexid),$($name),$($canevo),$($evo_stage),$($evo_stages),$($species.evolves_from_species.name),$($gen)"
}