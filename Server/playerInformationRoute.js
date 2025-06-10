const express = require("express");
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
            let description = "Not Found";
            let ign_change_date = new Date().toISOString().split('T')[0];
            let profile_change_date = new Date().toISOString().split('T')[0];
            let desc_change_date = new Date().toISOString().split('T')[0];
    
            if(findData.rows.length > 0){
                let data = findData.rows[0]

                status = "Success";
                diamond = data.diamond;
                profile = data.profile;
                inGameName = data.in_game_name;
                description = data.description;
                desc_change_date = new Date(data.desc_change_date).toISOString().split('T')[0];
                ign_change_date = new Date(data.ign_change_date).toISOString().split('T')[0];
                profile_change_date = new Date(data.profile_change_date).toISOString().split('T')[0];
            }

            res.status(200).json({ status: status, diamond: diamond, profile: profile, inGameName: inGameName, description: description, desc_change_date: desc_change_date, ign_change_date: ign_change_date, profile_change_date: profile_change_date });
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

            const player_data = await pool.query("SELECT * FROM player_infos WHERE username = $1", [sanitizeHTML(req.body.username)])

            if(player_data.rows.length > 0){
                let data = player_data.rows[0];
                let in_game_name = data.in_game_name;
                let ign_change_date = new Date(data.ign_change_date).toISOString().split("T")[0];

                let description = data.description;
                let desc_change_date = new Date(data.desc_change_date).toISOString().split("T")[0];

                let profile = data.profile;
                let profile_change_date = new Date(data.profile_change_date).toISOString().split("T")[0];

                let profile_hash = data.profile_hash

                //ign change
                if(req.body.inGameName && sanitizeHTML(req.body.inGameName) !== data.in_game_name){
                    const date = new Date();
                    date.setDate(date.getDate() + 7);

                    const query = await pool.query("UPDATE player_infos SET in_game_name = $1, ign_change_date = $2 WHERE username = $3 RETURNING *", [sanitizeHTML(req.body.inGameName), date.toISOString().split('T')[0], req.body.username]);

                    if(query.rows.length > 0){
                        in_game_name = query.rows[0].in_game_name;
                        ign_change_date = new Date(query.rows[0].ign_change_date).toISOString().split("T")[0];
                    }
                }

                //description change
                if(cleanDescription && sanitizeHTML(req.body.description) !== data.description && cleanDescription !== "No Description yet."){
                    const date = new Date();
                    date.setDate(date.getDate() + 7);

                    const query = await pool.query("UPDATE player_infos SET description = $1, desc_change_date = $2 WHERE username = $3 RETURNING *", [sanitizeHTML(cleanDescription), date.toISOString().split('T')[0], req.body.username]);

                    if(query.rows.length > 0){
                        description = query.rows[0].description;
                        desc_change_date = new Date(query.rows[0].desc_change_date).toISOString().split("T")[0];
                    }
                }

                //profile change
                if(req.body.profile){
                    let wait_for_upload = await upload_image(req.body.profile)
        
                    if(wait_for_upload){
                        const date = new Date();
                        date.setDate(date.getDate() + 7);

                        const query = await pool.query("UPDATE player_infos SET profile = $1, profile_change_date = $2, profile_hash = $3 WHERE username = $4 RETURNING *", [wait_for_upload.url, date.toISOString().split('T')[0], wait_for_upload.public_id , req.body.username]);

                        if(query.rows.length > 0){
                            profile = query.rows[0].profile;
                            profile_change_date = new Date(query.rows[0].profile_change_date).toISOString().split("T")[0];
                        }

                        if(wait_for_upload.public_id){
                            await delete_image(profile_hash)
                        }
                    }
                }

                res.status(200).json({ status: "Success", inGameName: in_game_name, description: description, profile: profile, ign_change_date: ign_change_date, profile_change_date: profile_change_date, desc_change_date: desc_change_date });
            }
        }
        catch(err){
            console.log(err)
        }
    });    

    return route;
}