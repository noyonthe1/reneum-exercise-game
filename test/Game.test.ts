import { ethers } from "hardhat";
import { expect } from "chai";
import path from "path";
import fs from 'fs';

export const getABIPath = (): string =>
  path.join(
    __dirname,
    '..',
    'artifacts',
    'contracts',
    'Game.sol',
    'Game.json'
  )

describe("Game contract", function () {
  let gameContract: any;
  let player1GameInstance: any;
  let player2GameInstance: any;
  let forwarderContract: any;
  let deployer: any;
  let player1: any;
  let player2: any;
  const gameJSON = JSON.parse(fs.readFileSync(getABIPath()).toString());

  before(async () => {
    const [_deployer, _player1, _player2] = await ethers.getSigners();
    deployer = _deployer;
    player1 = _player1;
    player2 = _player2;
    const forwarderContractFactory = await ethers.getContractFactory("Forwarder");
    forwarderContract = await forwarderContractFactory.deploy();
    await forwarderContract.deployed();
    
    const gameContractFactory = await ethers.getContractFactory("Game");
    gameContract = await gameContractFactory.deploy(forwarderContract.address);
    await gameContract.deployed();

    player1GameInstance = new ethers.Contract(gameContract.address, gameJSON.abi, player1);
    player2GameInstance = new ethers.Contract(gameContract.address, gameJSON.abi, player2);
  });

  it("Should have 2 generated character", async () => {
    let tx = await player1GameInstance.generateCharacter();
    await tx.wait();
    let character1 = await player1GameInstance.CharacterList(player1.address);
    console.log({character1});
    expect(character1[5].toString()).to.equal('1');

    tx = await player2GameInstance.generateCharacter();
    await tx.wait();
    let character2 = await player2GameInstance.CharacterList(player2.address);
    console.log({character2});
    expect(character2[5].toString()).to.equal('1');
  });

  it("Should have a boss", async () => {
		let boss1 = await gameContract.BossList(1);
    console.log({boss1});
    expect(boss1[0]).to.equal('Skolas');
	});

  it("Should attack the boss by player1", async () => {
    console.log('**************************Before*******************************');
    let boss1 = await gameContract.BossList(1);
    let bossHpPrev = Number(boss1[1].toString());
    console.log({bossHpPrev});
    let character = await gameContract.CharacterList(player1.address);
    let characterHpPrev = Number(character[1].toString());
    console.log({characterHpPrev});
    console.log('**************************Before*******************************');
    let tx = await player1GameInstance.attackBoss(false);
    await tx.wait();
    console.log('**************************After*******************************');
    boss1 = await gameContract.BossList(1);
    let bossHpNow = Number(boss1[1].toString());
    console.log({bossHpNow});
    character = await gameContract.CharacterList(player1.address);
    let characterHpNow = Number(character[1].toString());
    console.log({characterHpNow});
    console.log('**************************After*******************************');
    expect(bossHpPrev - bossHpNow).to.not.equal(0);
    expect(characterHpPrev - characterHpNow).to.not.equal(0);
	});

  it("Should attack the boss by player2", async () => {
    console.log('**************************Before*******************************');
    let boss1 = await gameContract.BossList(1);
    let bossHpPrev = Number(boss1[1].toString());
    console.log({bossHpPrev});
    let character = await gameContract.CharacterList(player2.address);
    let characterHpPrev = Number(character[1].toString());
    console.log({characterHpPrev});
    console.log('**************************Before*******************************');
    let tx = await player2GameInstance.attackBoss(false);
    await tx.wait();
    console.log('**************************After*******************************');
    boss1 = await gameContract.BossList(1);
    let bossHpNow = Number(boss1[1].toString());
    console.log({bossHpNow});
    character = await gameContract.CharacterList(player2.address);
    let characterHpNow = Number(character[1].toString());
    console.log({characterHpNow});
    console.log('**************************After*******************************');
    expect(bossHpPrev - bossHpNow).to.not.equal(0);
    expect(characterHpPrev - characterHpNow).to.not.equal(0);
	});

  it("Should kill the boss", async () => {
    console.log('**************************Before*******************************');
    let boss1 = await gameContract.BossList(1);
    let bossHpPrev = Number(boss1[1].toString());
    console.log({bossHpPrev});
    console.log('**************************Before*******************************');
    let tx = await player1GameInstance.attackBoss(false);
    await tx.wait();
    tx = await player2GameInstance.attackBoss(false);
    await tx.wait();
    tx = await player1GameInstance.attackBoss(false);
    await tx.wait();
    console.log('**************************After*******************************');
    boss1 = await gameContract.BossList(1);
    let bossHpNow = Number(boss1[1].toString());
    console.log({bossHpNow});
    console.log('**************************After*******************************');
    expect(bossHpNow).to.equal(0);
	});

  it("Should get the healing power", async () => {
    let tx = await player1GameInstance.claimHealingPower();
    await tx.wait();
    let character = await gameContract.CharacterList(player1.address);
    console.log({character});
    expect(character[6].toString()).to.equal('1');
	});

  it("Should heal player2", async () => {
    let character = await gameContract.CharacterList(player2.address);
    let characterHpPrev = Number(character[1].toString());
    console.log({characterHpPrev});
    let tx = await player1GameInstance.heal(player2.address);
    await tx.wait();
    character = await gameContract.CharacterList(player2.address);
    let characterHpNow = Number(character[1].toString());
    console.log({characterHpNow});
    expect(characterHpPrev - characterHpNow).to.not.equal(0);
	});
});