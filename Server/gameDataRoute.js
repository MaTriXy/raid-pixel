const express = require("express");
const route = express.Router();
let server_player_count = 0

route.post("/modifyPlayerCount", async (req, res)=>{
    try{
        server_player_count += req.body.count

        console.log(server_player_count)
        res.status(200).json({ status: "Success", count: server_player_count })
    }
    catch(err){
        console.log(err)
    }
});

module.exports = route;