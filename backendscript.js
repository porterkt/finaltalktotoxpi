function sendMessage() {
    const chatWindow = document.getElementById('chat-window');
    const userInput = document.getElementById('user-input');
    const message = userInput.value.trim();

    if (message) {
        //Create a new chat bubble for the user message
        const userBubble = document.createElement('div');
        userBubble.className = 'chat-bubble user';
        userBubble.textContent = message;

        //Add the bubble to the chat window
        chatWindow.appendChild(userBubble);

        //Clear input field
        userInput.value = '';

        //Allows for scrolling to the bottom of the chat window
        chatWindow.scrollTop = chatWindow.scrollHeight;

        //Sends input to the backend server through app.py
        fetch('http://127.0.0.1:5000/api/message', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ message: message }),
        })
        .then(response => response.json())
        .then(data => {
            //Creates a new chat bubble for each response
            const botBubble = document.createElement('div');
            botBubble.className = 'chat-bubble other';
            botBubble.textContent = data.response;

            //Adds bubble to chat window
            chatWindow.appendChild(botBubble);

            //Scrools to bottom of chat window
            chatWindow.scrollTop = chatWindow.scrollHeight;

            //Populates chemical data based on retrieved data
            populateChemicalsTable(data.chemicals);
        })
        .catch((error) => {
            console.error('Error:', error);
        });
    }
}

function populateChemicalsTable(chemicals) {
    const tbody = document.querySelector('.chemicals-table tbody');
    tbody.innerHTML = '';  //Clear previously existing data and rows

    chemicals.forEach(chemical => {
        const row = document.createElement('tr');
        const nameCell = document.createElement('td');
        nameCell.textContent = chemical;
        row.appendChild(nameCell);
        tbody.appendChild(row);
    });
}

//Listener function behind the submit button
document.querySelector('.submit-button').addEventListener('click', (event) => {
    const chemicalData = [];
    const rows = document.querySelectorAll('.chemicals-table tbody tr');
    rows.forEach(row => {
        const cell = row.querySelector('td');
        if(cell && cell.textContent){
            chemicalData.push(cell.textContent);
        }
    });

    //Simulate sending data to the backend
    console.log('Chemicals data submitted:', chemicalData);
    
    //Handle updating some output section
    document.querySelector('.description').textContent = 'Chemicals data submitted successfully! Processing...';
    
    //Simulate processing and updating the output
    setTimeout(() => {
        document.querySelector('.description').textContent = 'Submit Chemicals to Update';
    }, 2000); //Simulate slight processing delay
});
