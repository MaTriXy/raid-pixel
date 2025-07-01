const broadcastSocket = require("./websocket_broadcast");

let queue_match = []
let isMatchFound = false
let game_time_start = false

let game_minutes = 10
let game_seconds = 0

const max_players = 2

let queue_core_dmg = {}
let battle_player_info_map;

module.exports = (wss, pool)=>{
    wss.on('connection', (ws) => {
        // Listen for messages from clients
        ws.on('message', async (message) => {
            let parsed_message = JSON.parse(message);
            let socket_name = parsed_message.Socket_Name;

            //for finding match
            if(socket_name === "find_match"){
                var player_data = { id: parsed_message.player_id, ign: parsed_message.player_ign, profile: parsed_message.player_profile}
                var data = { "players": [player_data], "matchID": parsed_message.match_ID }
                let match_to_remove = []
                
                if(queue_match.length === 0 && parsed_message.status != "leave"){
                    queue_match.push(data)
                    isMatchFound = true
                }
                
                for(let queue of queue_match){
                    //this is where if a player cancel a match, it will be removed to a queue array
                    if(parsed_message.status == "leave"){
                        let players_index = queue.players.findIndex(q => q.id == parsed_message.player_id);

                        if(players_index > -1){
                            isMatchFound = false
                            queue.players.splice(players_index, 1)

                            if(queue.players.length <= 1){
                                match_to_remove.push(queue.matchID)
                            }
                            break;
                        }
                    }

                    //this is where the match if the array is filled with designated numbers of players
                    if(queue.players.length < max_players && !queue.players.some(q => q.id == parsed_message.player_id)){
                        queue.players.push(player_data)
                        isMatchFound = true
                    }

                    //start the match now
                    if(isMatchFound && queue.players.length === max_players){
                        let game_scene = ["Grassy Land"]

                        let player_map = queue.players.map((player, index) => ({
                            "id": player.id,
                            "ign": player.ign,
                            "profile": player.profile,
                            "class": (index % 2 === 0) ? "Defender" : "Attacker"
                        }))

                        broadcastSocket(
                            wss,
                            {
                                "Socket_Name": socket_name,
                                "player_map": player_map,
                                "Match_RoomID": queue.matchID,
                                "game_scene": game_scene[0]
                            }
                        )
                        battle_player_info_map = player_map

                        //add the match for removal
                        match_to_remove.push(queue.matchID)
                        isMatchFound = false
                        break;
                    }
                }

                //remove all the matches that completed with players
                if(match_to_remove.length > 0){
                    queue_match = queue_match.filter(entry => !match_to_remove.includes(entry.matchID))
                }

                console.log(JSON.stringify(queue_match))
            }

            //for start match
            else if(socket_name === "start_match"){
                broadcastSocket(
                    wss,
                    {
                        Socket_Name: socket_name,
					    player_map: parsed_message.player_map,
					    Match_RoomID: parsed_message.Match_RoomID,
					    game_scene: parsed_message.game_scene
                    }
                )
            }

            //for start game
            else if(socket_name === "start_game_" + ws.Spawn_Code){
                broadcastSocket(
                    wss,
                    {
                        Socket_Name: socket_name,
                        match_roomID: parsed_message.match_roomID
                    }
                )
            }

            //fall back for start game
            else if(socket_name == "game_is_start_" + ws.Spawn_Code){
                if(!game_time_start){
                    start_battle_time(parsed_message.spawn_code, wss)
                    game_time_start = true
                }
            }

            //for player spawn code
            else if(socket_name == "scene_code"){
                broadcastSocket(
                    wss,
                    {
                        "Socket_Name": socket_name,
                        "Spawn_Player_Code": parsed_message.Spawn_Player_Code
                    }
                )
                ws.Spawn_Code = parsed_message.Spawn_Player_Code
            }

            //for core health
            else if(socket_name === "core_health_" + ws.Spawn_Code){
                const key = ws.Spawn_Code
                queue_core_dmg[key] = parsed_message

                if(queue_core_dmg[key].wait_for_data) return;

                queue_core_dmg[key].wait_for_data = setTimeout(() => {
                    const latest_data = queue_core_dmg[key];

                    if(latest_data){
                        broadcastSocket(
                            wss,
                            {
                                "Socket_Name": socket_name,
                                "health": latest_data.health,
                                "max_health": latest_data.max_health
                            }
                        )    
                    }

                    delete queue_core_dmg[key]
                }, 1000);
            }

            //for receiving ping
            else if(socket_name === "ping"){
                broadcastSocket(
                    wss,
                    {
                        "Socket_Name": socket_name,
                        "timestamp": parsed_message.timestamp
                    }
                )
                
            }
        });

        ws.on('error', (err) => {
            console.error(err);
        });
    });
}

//for starting the game timer
function start_battle_time(spawn_code, wss){
    var game_start = setInterval(function(){
        game_seconds--

        if(game_seconds <= 0 && game_minutes > 0){
            game_seconds = 59
            game_minutes--
        }

        if(game_minutes <= 0){
            game_minutes = 0
        }

        if(game_minutes <= 0 && game_seconds <= 0){
            game_minutes = 0
            game_seconds = 0
            game_time_start = false
            clearInterval(game_start)
        }

        broadcastSocket(
            wss, 
            {
                Socket_Name: "battle_time_" + spawn_code,
                seconds: game_seconds,
                minutes: game_minutes
            }
        )

    }, 1000)
}