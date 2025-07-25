let count = 0

function pop_div(message){
    const parent_div = document.createElement("div")
    parent_div.setAttribute("class", "absolute -top-10 opacity-0 z-11 w-fit h-fit bg-white rounded-lg p-4");
    parent_div.setAttribute("id", "pop_div_" + count)

    const text = document.createElement("h1");
    text.setAttribute("class", "font-Pixelify-Sans text-center text-red-500 text-lg")
    text.appendChild(document.createTextNode(message))
    parent_div.appendChild(text)

    document.body.appendChild(parent_div)

    parent_div.style.animation = "pop_in 1s forwards"

    setTimeout(() => {
        parent_div.style.animation = "pop_out 1s forwards"

        parent_div.addEventListener("animationend", event=>{
            parent_div.remove()
        })
    }, 2000);
}

async function createAccount(){
    var username = document.getElementById("username_input");
    var password = document.getElementById("password_input");
    var confirm_password = document.getElementById("confirm_pass_input");

    if(!username.value || !password.value || !confirm_password.value){
        count++
        pop_div("All fields must be inputted.")
    }
    else if(username.value.length <= 4){
        count++
        pop_div("Username character length must above 4")
    }
    else if(password.value.length <= 4){
        count++
        pop_div("Password character length must above 4")
    }
    else if(password.value != confirm_password.value){
        count++
        pop_div("Password and confirm password not match.")
    }
    else{
        try{
            const createAcc = await fetch("/accountRoute/createAccount", {
                method: "POST",
                headers: {
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({ username: username.value, password: password.value })
            });

            const createAcc_data = await createAcc.json();

            if(createAcc_data.status == "Success"){
                alert("Account Created")
            }
            else{
                count++
                pop_div(createAcc_data.status)
            }
        }
        catch(err){
            console.log(err);
        }

        document.getElementById("username_input").value = "";
        document.getElementById("password_input").value = "";
        document.getElementById("confirm_pass_input").value = "";
    }
}

function modal_status(id, status){
    document.getElementById(id).style.display = status
}