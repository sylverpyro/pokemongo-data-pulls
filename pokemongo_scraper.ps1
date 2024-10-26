# Scrapes csv data from https://github.com/pokemon-go-api/pokemon-go-api?tab=readme-ov-file

$api = "https://pokemon-go-api.github.io/pokemon-go-api/api"
$api_mons = "$api/pokedex/id/"

$id = 133
$id_list = '1', '2', '3', '133', '150', '800'

foreach ( $id in $id_list ) { 

    #Write-Output "UIR: $api_mons/$id.json"

    $evolves = 'false'
    $evo_to = ''
    $mon = Invoke-WebRequest $api_mons/$id.json | ConvertFrom-json
    $name = $mon.names.english
    $gen = $mon.generation
    #Write-Debug "name: $name"
    foreach ( $evo_form in $($mon.evolutions) ) {
        #Write-Debug "Evolves to: $($evo_form.id)"
        $evolves = "true"
        $evo_to = "$evo_to" + "$($evo_form.id) "
    }
    $mega = $mon.hasMegaEvolution
    # Legendary, mythic, ect
    $class = $mon.pokemonClass
    $sta = $mon.stats.stamina
    $atk = $mon.stats.attack
    $def = $mon.stats.defense

    Write-Output "$id,$name,$evolves,$evo_to,$mega,$class,$gen,$sta,$atk,$def"
}