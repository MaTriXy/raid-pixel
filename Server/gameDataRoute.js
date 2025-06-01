const express = require("express");
const gameDataModel = require("./gameDataMongooseSchema");
const route = express.Router();

route.get("/getPlayerCount", async (req, res)=>{
    try{
        const get_count = await gameDataModel.findOne({})

        let status = "Failed";
        let count = 0

        if(get_count){
            status = "Success";
            count = get_count.playerCount;
        }

        res.status(200).json({ status: status, count: count })
    }
    catch(err){
        console.log(err)
    }
});

module.exports = route;