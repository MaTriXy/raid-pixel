const broadcastSocket = require("./websocket_broadcast");
const cloudinary = require("cloudinary").v2;

require("dotenv").config({ path: require("path").resolve(__dirname, "../keys.env")})

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

let queue_match = []
let isMatchFound = false
const max_players = 2
async function delete_image(profile_hash){
    try{
        if(profile_hash && profile_hash != "default_profile_vw2q2o"){
            cloudinary.uploader.destroy(profile_hash, function(result) { console.log(result) });
        }
    }
    catch(err){
        console.log(err);
    }
}

module.exports = (wss, pool)=>{
    wss.on('connection', (ws) => {
        // Listen for messages from clients
        ws.on('message', async (message) => {
            let parsed_message = JSON.parse(message);
            let socket_name = parsed_message.Socket_Name;

            //for connected player
            if(socket_name === "Player_Connected"){
                if(!ws.connected){
                    await modifyPlayerCount(1, pool);
                }

                broadcastSocket(
                    wss,
                    {
                        "Socket_Name": socket_name,
                        "Player_GameID": parsed_message.Player_GameID,
                    }
                )
                ws.GameID = parsed_message.Player_GameID;
                ws.username = parsed_message.Player_username;
                ws.connected = true
            }

            //for disconnected player
            else if(socket_name == "Player_Disconnect"){
                await modifyPlayerCount(-1, pool)
                
                broadcastSocket(
                    wss,
                    {
                        "Socket_Name": socket_name,
                        "Player_GameID": parsed_message.GameID
                    }
                )
            }

            //for player logout
            else if(socket_name === "Player_Logout"){
                broadcastSocket(
                    wss,
                    {
                        "Socket_Name": "Player_Disconnect",
                        "Player_GameID": parsed_message.GameID
                    }
                )
                setTimeout(() => {
                    ws.GameID = ""
                    ws.username = ""
                    ws.Spawn_Code = ""
                }, 1000);
            }

            //for player modify profile
            else if(socket_name === "ModifyProfile"){
                broadcastSocket(
                    wss,
                    {
                        "Socket_Name": socket_name,
                        "Player_GameID": parsed_message.Player_GameID,
                        "Player_inGameName": parsed_message.Player_inGameName
                    }
                )
            }

            //for finding match
            else if(socket_name === "find_match"){
                var player_data = { ign: parsed_message.player_ign, profile: parsed_message.player_profile}
                var data = { "players": [player_data], "matchID": parsed_message.match_ID }
                let match_to_remove = []
                
                if(queue_match.length === 0 && parsed_message.status != "leave"){
                    queue_match.push(data)
                    isMatchFound = true
                }
                
                for(let queue of queue_match){
                    //this is where if a player cancel a match, it will be removed to a queue array
                    if(parsed_message.status == "leave"){
                        let players_index = queue.players.findIndex(q => q.ign == parsed_message.player_ign);

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
                    if(queue.players.length < max_players && !queue.players.some(q => q.ign == parsed_message.player_ign)){
                        queue.players.push(player_data)
                        isMatchFound = true
                    }

                    //start the match now
                    if(isMatchFound && queue.players.length === max_players){
                        let game_scene = ["grassy_land"]

                        let player_map = queue.players.map((player, index) => ({
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
                console.log(parsed_message)
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
                broadcastSocket(
                    wss,
                    {
                        "Socket_Name": socket_name,
                        "health": parsed_message.health,
                        "Player_IGN": parsed_message.Player_IGN
                    }
                )
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

        ws.on('close', async () => {
            if(ws.GameID && ws.username){
                broadcastSocket(
                    wss,
                    {
                       "Socket_Name": "Player_Disconnect",
                        "Player_GameID": ws.GameID
                    }
                )
                ws.connected = false
                await deleteGuestPlayer_account(ws.username, pool);

                ws.GameID = ""
                ws.username = ""
                ws.Spawn_Code = ""
            }
        });

        ws.on('error', (err) => {
            console.error(err);
        });
    });
}

async function deleteGuestPlayer_account(username, pool) {
    try{
        const query = await pool.query('SELECT * FROM account WHERE username = $1', [username]);

        if(query.rows.length === 0){
            console.log("Account does not exist");
            return;
        }

        if(query.rows[0].account_type == "Guest"){
            const find_player = await pool.query('SELECT * FROM player_infos WHERE username = $1', [username]);

            if(find_player.rows.length > 0){
                const image_name = find_player.rows[0].profile_hash;

                if(image_name){
                    await delete_image(image_name);
                }
            }

            await pool.query('DELETE FROM account WHERE username = $1', [username]);
            await pool.query('DELETE FROM player_infos WHERE username = $1', [username]);
        }
        else{
            await pool.query('UPDATE account SET isonline = $1 WHERE username = $2', [false, username]);
        }
        await modifyPlayerCount(-1, pool);
    }
    catch(err){
        console.log(err);
    }
}

async function modifyPlayerCount(count, pool) {
    try{
        await pool.query("UPDATE game_data SET player_count = GREATEST(player_count + $1, 0)", [count])
    }
    catch(err){
        console.log(err)
    }
}