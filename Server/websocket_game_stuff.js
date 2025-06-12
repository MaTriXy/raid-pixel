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
            else if(socket_name == "find_match"){
                var data = { "gameID": [parsed_message.Player_GameID], "matchID": parsed_message.match_ID }
                let match_to_remove = []
                
                if(queue_match.length === 0 && parsed_message.status != "leave"){
                    queue_match.push(data)
                    isMatchFound = true
                }
                
                for(let queue of queue_match){
                    //this is where if a player cancel a match, it will be removed to a queue array
                    if(parsed_message.status == "leave"){
                        let gameID_index = queue.gameID.indexOf(parsed_message.Player_GameID)

                        if(gameID_index > -1){
                            isMatchFound = false
                            queue.gameID.splice(gameID_index, 1)

                            if(queue.gameID.length <= 1){
                                match_to_remove.push(queue.matchID)
                            }
                            break;
                        }
                    }

                    //this is where the match if the array is filled with designated numbers of players
                    if(queue.gameID.length < max_players && !queue.gameID.includes(parsed_message.Player_GameID)){
                        queue.gameID.push(parsed_message.Player_GameID)
                        isMatchFound = true
                    }

                    //start the match now
                    if(isMatchFound && queue.gameID.length === max_players){
                        let game_scene = ["grassy_land"]
                        let class_type = []

                        queue.gameID.forEach((player, index) => {
                            class_type.push({ gameID: player, class: (index % 2 === 0) ? "Defender" : "Attacker" }) 
                        });

                        broadcastSocket(
                            wss,
                            {
                                "Socket_Name": socket_name,
                                "Players_GameID": queue.gameID,
                                "Match_RoomID": queue.matchID,
                                "game_scene": game_scene[0],
                                "class_type": class_type
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

                //for cleaning up the empty matches
                queue_match = queue_match.filter(queue => queue.gameID.length > 0);

                console.table(queue_match)
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