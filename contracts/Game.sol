//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./libraries/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./gsn/BaseRelayRecipient.sol";

contract Game is ERC721, Ownable, BaseRelayRecipient {

    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    uint256 MAX_SUPPLY = 9999;

    struct Character {
        string name;
        uint256 hp;
        uint256 xp;
        uint256 maxHp;
        uint256 attackDamage;
        uint256 level;
        uint256 heal;
        uint256 fireball;
    }

    struct Boss {
        string name;
        uint256 hp;
        uint256 maxHp;
        uint256 attackDamage;
    }

    mapping(address => Character) public CharacterList;

    string[] internal _characterNames = ['Gordon Freeman', 'Mario', 'Shodan', 'The Nameless One', 'Lara Craft'];

    string[] internal _bossNames = ['Skolas', 'Emerald Weapon', 'Mike Tyson', 'Fume Night', 'High Dragon'];

    mapping(uint256 => Boss) public BossList;

    mapping (uint256 => string) private _tokenURIs;

    string private _baseURIextended;

    event AttackComplete(uint256 newBossHp, uint256 newPlayerHp);
    event PlayerDead(bool death);
    event BossDead(bool death);
    event PlayerHealed(address requestFrom, address healedPlayer);

    constructor(address _trustedForwarder) ERC721("Heroes", "HERO") {
        trustedForwarder = _trustedForwarder;
        generateBosses();
    }

    function generateCharacter() public {
        uint256 _index = random(4,0);
        CharacterList[_msg_sender()].name = _characterNames[_index];
        CharacterList[_msg_sender()].hp = random(100,90);
        CharacterList[_msg_sender()].xp = 0;
        CharacterList[_msg_sender()].maxHp = CharacterList[_msg_sender()].hp;
        CharacterList[_msg_sender()].attackDamage = random(15,10);
        CharacterList[_msg_sender()].level = 1;
        CharacterList[_msg_sender()].heal = 0;
        CharacterList[_msg_sender()].fireball = 0;
        safeMint(_msg_sender(), 'uri');
    }

    function safeMint(address to, string memory uri) public {
        require(_tokenIdCounter.current() <= MAX_SUPPLY, "I'm sorry we reached the cap");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
    function generateBosses() internal {
        for (uint256 index = 1; index <= 5; index++) {
            generateBoss(index);
        }
    }

    function generateBoss(uint256 index) internal {
        BossList[index].name = _bossNames[index.sub(1)];
        BossList[index].hp = index.mul(4).add(50);
        BossList[index].maxHp = BossList[index].hp;
        BossList[index].attackDamage = index.mul(2).add(10);
    }

    function customizeBoss(uint256 level, string memory bossName, uint256 hp, uint256 attackDamage) public onlyOwner {
        require(BossList[level].hp == 0, "The boss is still alive.");
        BossList[level].name = bossName;
        BossList[level].hp = hp;
        BossList[level].maxHp = hp;
        BossList[level].attackDamage = attackDamage;
    }

    function random(uint maxNumber,uint minNumber) public view returns (uint amount) {
        amount = uint(keccak256(abi.encodePacked(block.timestamp, _msg_sender(), block.number))) % (maxNumber-minNumber);
        amount = amount + minNumber;
        return amount;
    }
    
    function heal(address toPlayer) public {
        require(_msg_sender() != toPlayer, "A player can not heal himself.");
        require(CharacterList[_msg_sender()].level >= 2, "A player can not heal if he has level less than two.");
        require(CharacterList[_msg_sender()].heal > 0, "Insufficient healing power.");

        CharacterList[toPlayer].hp = CharacterList[toPlayer].hp.add(5);

        if(CharacterList[toPlayer].hp > CharacterList[toPlayer].maxHp) {
            CharacterList[toPlayer].hp = CharacterList[toPlayer].maxHp;
        }
        // in a single level a player can heal upto five times.
        CharacterList[_msg_sender()].heal = CharacterList[_msg_sender()].heal.sub(1);
        emit PlayerHealed(_msg_sender(), toPlayer);
    }

    function claimHealingPower() public {           
        require(CharacterList[_msg_sender()].xp >= 15, "Insufficient XP for getting healing power.");
        CharacterList[_msg_sender()].xp = CharacterList[_msg_sender()].xp.sub(15);
        CharacterList[_msg_sender()].heal = CharacterList[_msg_sender()].heal.add(1);
    }

    function claimFireballSpell() public {           
        require(CharacterList[_msg_sender()].xp >= 25, "Insufficient XP for getting fireball spell.");
        CharacterList[_msg_sender()].xp = CharacterList[_msg_sender()].xp.sub(25);
        CharacterList[_msg_sender()].fireball = CharacterList[_msg_sender()].fireball.add(1);
        // expirationDate = now + 1 days;
    }

    function attackBoss(bool isDoubleDamage) public {
        Character storage _player = CharacterList[_msg_sender()];
        Boss storage _boss = BossList[_player.level];

        require(_player.hp > 0, "The player is already dead, he can't attack anyone.");
        require(_boss.hp > 0, "The boss is already dead, he can't attack the player.");

        uint256 _playerAttackDamage = 0;
        
        if(isDoubleDamage) {
            _playerAttackDamage = _player.attackDamage.mul(2);
        } else {
            _playerAttackDamage = _player.attackDamage;
        }

        /**
        if(_player.level == MAX_LEVEL) {
            restartGame();
        }

        if(isBossDefeated) {
            // All the players level will go up.
        }
        **/

        _player.xp = _player.xp.add(5);

        if (_boss.hp < _playerAttackDamage) {
            _boss.hp = 0;
            CharacterList[_msg_sender()].level = CharacterList[_msg_sender()].level.add(1);
            emit BossDead(true);
        } else {
            _boss.hp = _boss.hp.sub(_playerAttackDamage);
        }

        if (_player.hp < _boss.attackDamage) {
            _player.hp = 0;
            emit PlayerDead(true);
        } else {
            _player.hp = _player.hp.sub(_boss.attackDamage);
        }

        emit AttackComplete(_boss.hp, _player.hp);
    }
    
    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();
        
        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    // function rewardCalculation() public onlyOwner {

    // }
}