const express = require("express");
const { Result } = require("pg");
const route = express.Router();
const sanitizeHTML = require("sanitize-html")
const cloudinary = require("cloudinary").v2;
const { v4: uuidv4 } = require('uuid');

require("dotenv").config({ path: require("path").resolve(__dirname, "../keys.env")})

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});


module.exports = function(pool){
    route.post("/playerData", async (req, res)=>{
        try{
            const findData = await pool.query("SELECT * FROM player_infos WHERE username = $1", [sanitizeHTML(req.body.username)]);

            let status = "Failed";
            let diamond = 0;
            let profile = "Invalid";
            let inGameName = "Not Found";
            let description = "Not Found"
    
            if(findData.rows.length > 0){
                let data = findData.rows[0]

                status = "Success";
                diamond = data.diamond;
                profile = data.profile;
                inGameName = data.in_game_name;
                description = data.description;
            }
    
            res.status(200).json({ status: status, diamond: diamond, profile: profile, inGameName: inGameName, description: description });
        }
        catch(err){
            console.log(err)
        }
    });
    
    async function upload_image(profile){
        try{
            if(profile){
                const fullBase64 = `data:image/png;base64,${profile}`;
                const uploadResult = await cloudinary.uploader.upload(
                    fullBase64, {
                        public_id: 'Profile_' + uuidv4(),
                        folder: "Profile"
                    }
                )
                .catch((error) => {
                    console.log(error);
                    return {}
                });
                
                return uploadResult;
            }
        }
        catch(err){
            console.log(err);
            return {}
        }
    }

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
    
    route.post("/modifyPlayerData", async (req, res)=>{
        try{
            const rawDescription = req.body.description || "";
            const cleanDescription = rawDescription.trim() === "" ? "No Description yet." : rawDescription;
    
            const update_fields = {
                in_game_name: sanitizeHTML(req.body.inGameName),
                description: sanitizeHTML(cleanDescription)
            }
    
            if(req.body.profile){
                let wait_for_upload = await upload_image(req.body.profile)
    
                if(wait_for_upload){
                    update_fields.profile = wait_for_upload.url;
                    update_fields.profile_hash = wait_for_upload.public_id;
                }
            }

            let status = "Failed";
            let in_game_name = "Not Found";
            let description = "Not Found";
            let profile = ""

            const player_data = await pool.query("SELECT * FROM player_infos WHERE username = $1", [sanitizeHTML(req.body.username)])

            if(player_data.rows.length > 0){
                let data = player_data.rows[0]
                let profile_result = update_fields.profile || data.profile;
                let profile_hash_result = update_fields.profile_hash || data.profile_hash;
                let in_game_name_result = update_fields.in_game_name || data.in_game_name;
                let description_result = update_fields.description || data.description;

                await delete_image(data.profile_hash)

                const query = await pool.query("UPDATE player_infos SET in_game_name = $1, profile = $2, profile_hash = $3, description = $4 WHERE username = $5 RETURNING *", [in_game_name_result, profile_result, profile_hash_result, description_result, sanitizeHTML(req.body.username)]);

                if(query.rows.length > 0){
                    let data = query.rows[0];
    
                    status = "Success";
                    in_game_name = data.in_game_name;
                    description = data.description;
                    profile = data.profile;
                }
            }
    
            res.status(200).json({ status: status, inGameName: in_game_name, description: description, profile: profile });
        }
        catch(err){
            console.log(err)
        }
    });    

    return route;
}