const accountModel = require("./accountMongooseSchema");
const playerInfoModel = require("./playerInformationMongooseSchema");
const broadcastSocket = require("./websocket_broadcast");

const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

require("dotenv").config({ path: require("path").resolve(__dirname, "../keys.env")})

async function delete_image(profile_hash){
    try{
        if(profile_hash != "ajVzRmV"){
            const deleteImg = await fetch(`https://api.imgur.com/3/image/${profile_hash}`, {
                method: "DELETE",
                headers: {
                    Authorization: `Bearer ${process.env.IMGUR_ACCESS_TOKEN}`
                }
            });

            const deleteImg_res = await deleteImg.json();

            if(!deleteImg_res.success){
                console.log(deleteImg_res)
            }
        }
    }
    catch(err){
        console.log(err);
    }
}

module.exports = (wss)=>{
    wss.on('connection', (ws) => {
        // Listen for messages from clients
        ws.on('message', async (message) => {
            let parsed_message = JSON.parse(message);
            let socket_name = parsed_message.Socket_Name;

            //for connected player
            if(socket_name === "Player_Connected"){
                broadcastSocket(
                    wss,
                    {
                        "Socket_Name": socket_name,
                        "Player_GameID": parsed_message.Player_GameID,
                    }
                )
                ws.GameID = parsed_message.Player_GameID;
                ws.username = parsed_message.Player_username;
                
                ws.send(JSON.stringify(
                    {
                        "Socket_Name": socket_name,
                        "Player_GameID": parsed_message.Player_GameID
                    }
                ));
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
                }, 2000);
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
                console.log(ws.username + " closed the game.")
                await deleteGuestPlayer_account(ws.username);
            }
        });

        ws.on('error', (err) => {
            console.error(err);
        });
    });
}

async function deleteGuestPlayer_account(username) {
    try{
        let findAcc = await accountModel.findOne({ username: username, account_type: "Guest" });

        if(findAcc){
            console.log("this is a guest account, isOnline: " + findAcc.isOnline)
            
            if(findAcc.isOnline){
                await modifyPlayerCount(-1);
            }
            const find_player = await playerInfoModel.findOne({ username: username })

            if(find_player){
                await delete_image(find_player.profile_hash);
            }

            await playerInfoModel.findOneAndDelete({ username: username });
            await accountModel.findOneAndDelete({ username: username, account_type: "Guest" });
        }
        else{
            const findAcc = await accountModel.findOneAndUpdate({ username: username, isOnline: true, account_type: "Player" }, { $set: { isOnline: false }}, { new: true })

            if(!findAcc){
                console.log("Account already logged out");
            }
        }
    }
    catch(err){
        console.log(err);
    }
}

async function modifyPlayerCount(count){
    try{
        const gameDataModel = require("./gameDataMongooseSchema")

        await gameDataModel.findOneAndUpdate(
            {}, 
            { $inc: { playerCount: count }},
            { new: true, upsert: true }
        );

        //clamp to zero when it become negative
        await gameDataModel.findOneAndUpdate(
            {}, 
            { $max: { playerCount: 0 }},
            { new: true }
        );
    }
    catch(err){
        console.log(err)
    }
}